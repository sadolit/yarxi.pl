package JDCommon;

# Yarxi.PL - Консольный интерфейс к словарю Яркси.
#
# Оригинальная программа и база данных словаря - (c) Вадим Смоленский.
# (http://www.susi.ru/yarxi/)
#
# Copyright (C) 2007-2010  Андрей Смачёв aka Biga.
#
# This program is free software: you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# version 2 as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, see <http://www.gnu.org/licenses/>
# or write to the Free Software Foundation, Inc., 51 Franklin Street,
# Fifth Floor, Boston, MA 02110-1301, USA.
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

use strict;
use utf8;
use File::Basename;
use DBI;

use Carp;

# Export symbols
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(
	$search_show_all
	$iteration_mark

	&errmsg &fail

	&read_config &read_config_file &read_colorscheme_file
	&search_compound &search_kunyomi &search_kunyomi_rusnick
	&search_kunyomi_russian &search_onyomi &search_tango_reading
	&search_tango_russian &search_unicode
	$search_show_all
	$search_show_one
	&fetch_kanji_full &fetch_tango_full
	&search_rads &split_kanji

	&kanji_from_unicode &max
	&ref_push
	&new_dom_object
	&make_dom_object &make_text_obj
	&add_child
	&arrays_equal &is_array
);

my $db_filename = $FindBin::Bin."/yarxi_u.db";
( -f $db_filename ) or fail("Can't find database file: '$db_filename'");
my $dbh = DBI->connect( "dbi:SQLite:dbname=$db_filename", "", "");

#----------------------------------------------------------------------

our $search_show_all = 0;

our $search_show_one = 0;

our $iteration_mark = chr(0x3005); # Символ повторения иероглифа.
#-----------------------------------------------------------------------

sub errmsg {
	my ($msg) = @_;

	utf8::encode($msg) if utf8::is_utf8($msg);
	print STDERR "\n !!! Error : $msg\n"; # DBG:
}

sub fail {
	errmsg( defined $_[0] ? $_[0] : "Без описания" );
	Carp::confess();
}

#----------------------------------------------------------------------

sub read_config_file {
	my ($file, $config) = @_;

	( -f $file ) or return $config;

	my $fh;
	open $fh, $file or fail "Can't open file '$file'";

	while (my $line = <$fh>) {
		chomp $line;
		$line =~ s/^\s+//;
		$line =~ s/\s+$//; # Remove spaces
		next if $line =~ /^#/; # пропускаем комметарии
		next if $line =~ /^$/; # пропускаем пустые строки

		my ($key, $value);
		if ( $line =~ /^(\S+)\s*(.*)$/ ) {
			$key = $1;
			$value = $2;
		}
		else {
			fail "$file:$.: Не могу понять строку '$line'";
		}

		$config->{$key} = $value;

		if ( $key eq 'scheme' ) {
			if ( $value !~ /^\// ) { # не начинается со слеша
				$value = dirname($file).'/'.$value;
				$config->{$key} = $value;
			}
		}
		elsif ( $key eq 'cur_trans_type' ) {
			( $value =~ /^(romaji|kiriji|hiragana|katakana)$/ )
				or fail "$file:$.: Wrong cur_trans_type '$value'";
		}
		elsif ( $key =~ /^(italic|term_width)$/ ) {
			# do nothing
		}
		else {
			fail "$file:$.: Неизвестный параметр '$key'";
		}
	}
	return $config;
}

sub read_colorscheme_file {
	my ($file) = @_;

	my $fh;
	open $fh, $file or fail "Can't open file '$file'";

	my %colors;
	my %pale_map;

	while (my $line = <$fh>) {
		chomp $line;
		$line =~ s/^\s+//;
		$line =~ s/\s+$//; # Remove spaces

		next if $line =~ /^#/; # пропускаем комметарии
		next if $line =~ /^$/; # пропускаем пустые строки

		if ( $line =~ /^([A-Za-z_\d\-]+)\s+([A-Za-z_\d\-]+|\[\d+)$/ ) {
		# Определение цвета.
			my $key = $1;
			my $value = $2;

			if ( $value =~ /^\[/ ) {
			# Определение через цветовой код
				$colors{$key} = "\e".$value."m";
			}
			else {
			# Определение через уже добавленный цвет
				( defined $colors{$value} ) or fail "Цвет ещё не определён: '$value'";

				$colors{$key} = $colors{$value};
			}
		}
		elsif ( $line =~ /^([A-Za-z_\d\-]+|\[\d+)\s*>\s*([A-Za-z_\d\-]+|\[\d+)$/ ) {
		# Определение бледного цвета
			my $key = $1;
			my $value = $2;

			if ( $key !~ /^\[/ ) {
				( defined $colors{$key} ) or fail "Цвет ещё не определён: '$key'";
				$key = $colors{$key};
			} else {
				$key = "\e".$key."m";
			}

			if ( $value !~ /^\[/ ) {
				( defined $colors{$value} ) or fail "Цвет ещё не определён: '$value'";
				$value = $colors{$value};
			} else {
				$value = "\e".$value."m";
			}

			$pale_map{$key} = $value;
		}
		else {
			fail "Не могу понять строку: $line";
		}
	}
	return (\%colors, \%pale_map);
}

sub read_config {
	# Читаем конфиги
	my $config = {};

	# Файл конфига в директории программы
	read_config_file($FindBin::Bin."/config/yarxi.conf", $config);

	# Файл конфига в директории ~/.config перекрывает конфиг в директории программы
	read_config_file( $ENV{HOME}."/.config/yarxi/yarxi.conf", $config );

	# Файл конфига в директории пользователя перекрывает все конфиги
	read_config_file( $ENV{HOME}."/.yarxi/yarxi.conf", $config );

	return $config;
}

#-----------------------------------------------------------------------

# Поиск

sub search_kunyomi {
	my ($txt) = @_;

	$txt =~ s/'//g; # Убираем кавычки для безопасности

	$txt =~ s/^\.+/%/;
	$txt =~ s/\.+$/%/;

	$txt = '%*'.$txt if $txt !~ /^%/;
	$txt = $txt.'*%' if $txt !~ /%$/;

	my $sth = $dbh->prepare("SELECT Nomer, Uncd FROM Kanji WHERE (Kunyomi LIKE ?)");
	$sth->execute($txt);

	my $res = [];
	while ( my $row = $sth->fetchrow_hashref() ) {
		push @$res, [$row->{'Nomer'}, $row->{'Uncd'}];
	}
	$sth->finish();

	return $res;
}

sub search_tango_reading {
	my ($txt) = @_;

	$txt =~ s/'//g; # Убираем кавычки для безопасности

	$txt =~ s/^\.+/%/;
	$txt =~ s/\.+$/%/;

	my $sql =
			"SELECT Nomer FROM Tango"
			." WHERE (Reading LIKE '$txt')"
			.($txt =~ /^%/ ? $txt =~ /%$/ ?
				"" : " OR (Reading LIKE '$txt*%')" :
			" OR (Reading LIKE '$txt*%') OR (Reading LIKE '%*$txt*%')");

	my $sth = $dbh->prepare( $sql );
	$sth->execute();

	my $res = [];
	while ( my $row = $sth->fetchrow_hashref() ) {
		push @$res, $row->{'Nomer'};
	}
	$sth->finish();

	return $res;
}

sub search_unicode {
	my ($uncd) = @_;

	my $sth = $dbh->prepare("SELECT Nomer FROM Kanji WHERE Uncd=?");
	$sth->execute($uncd);

	my $row = $sth->fetchrow_hashref();

	return 0 if !$row;

	return $row->{'Nomer'};
}

sub search_onyomi {
	my ($txt) = @_;

	$txt =~ s/'//g; # Убираем кавычки для безопасности

	$txt =~ s/^\.+/%/;
	$txt =~ s/\.+$/%/;

	$txt = '%*'.$txt if $txt !~ /^%/;
	$txt = $txt.'*%' if $txt !~ /%$/;

	my $sth = $dbh->prepare("SELECT Nomer, Uncd FROM Kanji WHERE (Onyomi LIKE ?)");
	$sth->execute($txt);

	my $res = [];
	while ( my $row = $sth->fetchrow_hashref() ) {
		push @$res, [$row->{'Nomer'}, $row->{'Uncd'}];
	}
	$sth->finish();

	return $res;
}

sub search_kunyomi_rusnick {
	my ($txt) = @_;

	$txt =~ s/'//g; # Убираем кавычки для безопасности

	$txt =~ s/^\.+/%/;
	$txt =~ s/\.+$/%/;

	my $sth = $dbh->prepare("SELECT Nomer, Uncd FROM Kanji WHERE (RusNick LIKE ?)");
	$sth->execute($txt);

	my $res = [];
	while ( my $row = $sth->fetchrow_hashref() ) {
		push @$res, [$row->{'Nomer'}, $row->{'Uncd'}];
	}
	$sth->finish();

	return $res;
}

sub search_kunyomi_russian {
	my ($txt) = @_;

	$txt =~ s/'//g; # Убираем кавычки для безопасности

	$txt =~ s/^\.+/%/;
	$txt =~ s/\.+$/%/;

	$txt = '%'.$txt if $txt !~ /^%/;
	$txt = $txt.'%' if $txt !~ /%$/;

	my $sth = $dbh->prepare("SELECT Nomer, Uncd FROM Kanji WHERE (Russian LIKE ?)");
	$sth->execute($txt);

	my $res = [];
	while ( my $row = $sth->fetchrow_hashref() ) {
		push @$res, [$row->{'Nomer'}, $row->{'Uncd'}];
	}
	$sth->finish();

	return $res;
}

sub search_tango_russian {
	my ($txt) = @_;

	$txt =~ s/'//g; # Убираем кавычки для безопасности

	$txt =~ s/^\.+/%/;
	$txt =~ s/\.+$/%/;

	$txt = '%'.$txt if $txt !~ /^%/;
	$txt = $txt.'%' if $txt !~ /%$/;

	my $sth = $dbh->prepare(
			"SELECT Nomer FROM Tango WHERE (Russian LIKE ?)"
		);
	$sth->execute($txt);

	my $res = [];
	while ( my $row = $sth->fetchrow_hashref() ) {
		push @$res, $row->{'Nomer'};
	}
	$sth->finish();

	return $res;
}


sub search_compound {
	my ($txt) = @_;

	my @arr = ();

	while ( $txt =~ /([一-龥])/g ) { # выделяем иероглифы
		my $uncd = ord ($1);

		my $sth = $dbh->prepare("SELECT Nomer FROM Kanji WHERE Uncd=?");
		$sth->execute($uncd);

		my $row = $sth->fetchrow_hashref();

		if ( !$row ) {
			next;
		}

		push @arr, $row->{'Nomer'};
	}

	if ( !@arr ) {
		return undef;
	}

	my $sql = "SELECT Nomer FROM Tango WHERE";
	my $where = "";

	if ($search_show_one ne 0) {
		my $arr_size = @arr;
		# You can't look up for words with more than 4 kanji.
		if ($arr_size >= 4) {
			return -1;
		}
		if ($arr_size < 4) {
			for (my $index = $arr_size; $index <4; $index++) {
				# 0 is no kanji.
				push(@arr, 0);
			}		
		}	
		my $ind = 1;
		foreach my $n ( @arr ) {
			$where .= " AND" if $where;
			$where .= " K$ind=$n ";#
			$ind++;
		}
		$where .= " AND Kana='' ";

	}
	else {
		foreach my $n ( @arr ) {
			$where .= " AND" if $where;
			$where .= " (K1=$n OR K2=$n OR K3=$n OR K4=$n)";
		}
	}
	$sql .= $where;

	my $sth = $dbh->prepare($sql);
	$sth->execute();

	my $res = [];
	while ( my $row = $sth->fetchrow_hashref() ) {
		push @$res, $row->{'Nomer'};
	}
	$sth->finish();

	return $res;
}

# Кэши для запросов к базе.
my $kanji_cache = {};
my $tango_cache = {};

# Периодически кэши лучше сбрасывать, чтобы не загружать память.
sub cleanup() {
	$kanji_cache = {};
	$tango_cache = {};
}

my $sth_kanji_full = $dbh->prepare("SELECT * FROM Kanji WHERE Nomer= ?;");

sub fetch_kanji_full {
	my ($num) = @_;
	( defined $num ) or fail "Undef kanji id: '$num'";
	( $num eq int($num) )  or fail "Wrong kanji id: '$num'";
	( $num > 0 ) or fail "Wrong kanji id: '$num'";

	if ( defined $kanji_cache->{$num} ) { # Смотрим в кэш
		return $kanji_cache->{$num};
	}
	# else
	$sth_kanji_full->execute($num);

	my $row = $sth_kanji_full->fetchrow_hashref();
	if ( $row ) {
		# Декодируем UTF-8
		utf8::decode( $row->{'Russian'} );
		utf8::decode( $row->{'RusNick'} );

		# Добавляем в кэш
		$kanji_cache->{$num} = $row;
	}
	$sth_kanji_full->finish();

	return $row;
}
#----------------------------------------------------------------------

my $sth_tango_full = $dbh->prepare("SELECT * FROM Tango WHERE Nomer=?");

sub fetch_tango_full {
	my ($tango_id) = @_;
	( defined $tango_id ) or fail "Undef tango id: '$tango_id'";
	$tango_id =~ s/^0+//; # удаляем нули в начале числа
	( $tango_id eq int($tango_id) )  or fail "Wrong tango id: '$tango_id'";
	( $tango_id > 0 ) or fail "Wrong tango id: '$tango_id'";

	# Проверяем кэш
	if ( defined $tango_cache->{$tango_id} ) {
		return $tango_cache->{$tango_id};
	}
	# else
	$sth_tango_full->execute($tango_id);

	my $row = $sth_tango_full->fetchrow_hashref();
	if ( $row ) {
		# Декодируем UTF-8
		utf8::decode( $row->{'Russian'} );

		# Добавляем в кэш
		$tango_cache->{$tango_id} = $row;
	}

	return $row;
}
#----------------------------------------------------------------------

sub fetch_rad_code {
	my $sth = $dbh->prepare("SELECT * FROM Radical");

	$sth->execute();

	my $rad_uncd = {};
	my $uncd_rad = {};

	while ( my $row = $sth->fetchrow_hashref() ) {
		my $nomer = $row->{'Nomer'};
		my $uncd = $row->{'Uncd'};

		$rad_uncd->{$nomer} = $uncd;

		if ( !defined $uncd_rad->{$uncd} ) {
			$uncd_rad->{$uncd} = $nomer;
		} else {
			if ( ref($uncd_rad->{$uncd}) eq "" ) {
				$uncd_rad->{$uncd} = [$uncd_rad->{$uncd}];
			}
			push @{$uncd_rad->{$uncd}}, $nomer;
		}
	}

	return ($rad_uncd, $uncd_rad);
}

#----------------------------------------------------------------------

sub split_into_rads {
	my ($kanji) = @_;

	my $sth = $dbh->prepare("SELECT Radical, Uncd FROM Unfolded"
		." LEFT JOIN Radical on Nomer=Radical"
		." WHERE KNomer=?");
	$sth->execute($kanji);

	my $rads = [];
	my $rad_u = {};
	while ( my $row = $sth->fetchrow_hashref() ) {
		push @$rads, $row->{'Radical'};
		$rad_u->{$row->{'Radical'}} = $row->{'Uncd'};
	}
	return ($rads, $rad_u);
}

sub search_rads {
	my (@chars) = @_;

	my ($rad_uncd, $uncd_rad) = fetch_rad_code();

	my $res = "";

	my %rads = ();

	foreach my $chr ( @chars ) {
		my $rad = $uncd_rad->{ord($chr)};
		if ( $rad ) {
			if ( ref($rad) eq "" ) {
				$rads{$rad} = 1;
			} else {
				foreach my $r ( @$rad ) {
					$rads{$r} = 1;
				}
			}
		} else { # не радикал
			# может, иероглиф?
			my $kanji = search_unicode(ord($chr));
			if ( $kanji ) {
				my ($spl) = split_into_rads($kanji);
				if ( @$spl ) {
					$rads{$_} = 1 foreach @$spl;
				} else {
					$res .= "Непонятный символ: $chr\n";
				}
			} else {
				$res .= "Непонятный символ: $chr\n";
			}
		}
	}

	my $limit = 100;
	my $sql = "SELECT KNomer, Uncd, SUM(Score) s, COUNT(Score) c FROM Unfolded"
		." LEFT JOIN Kanji on Nomer=KNomer"
		." WHERE Radical IN (".join(",", ("?") x keys(%rads)).")"
		." GROUP BY KNomer ORDER BY s DESC, c DESC"
		.($search_show_all ? "" : " LIMIT $limit")
		;
	my $sth = $dbh->prepare($sql);
	$sth->execute(keys %rads);

	my $n = 0;
	while ( my $row = $sth->fetchrow_hashref() ) {
		$res .= chr($row->{'Uncd'})." ";
		$n++;
	}
	if ( $res ) { $res .= "\n"; }
	if ( !$search_show_all && $n == $limit ) {
		$res .= "Показано $limit иероглифов. Используйте -a, чтобы увидеть больше.\n";
	}
	return $res;
}

sub split_kanji($) {
	my ($chr) = @_;

	my $res = "";

	my $kanji = search_unicode(ord($chr));
	if ( $kanji ) {
		my ($rads, $rad_u) = split_into_rads($kanji);
		if ( @$rads ) {
			foreach my $rad ( @$rads ) {
				my $uncd = $rad_u->{$rad};
				next if !$uncd;
				my $c = chr($uncd);
				next if ( $c eq '?' || $c eq '-' );
				$res .= $c." ";
			}
			$res .= "\n";
		} else {
			$res .= "Непонятный символ: $chr\n";
		}
	} else {
		$res .= "Непонятный символ: $chr\n";
	}
}

sub kanji_from_unicode($$) {
	my ($nomer, $unicode) = @_;
	return chr($unicode);
}

sub max {
	my $res = 0;
	foreach ( @_ ) {
		if ( $_ > $res ) { $res = $_; }
	}
	return $res;
}

sub ref_push($@) { push @{$_[0] ||= []}, @_[1..$#_] }

# Data Object Model functions

sub new_dom_object {
	if ( @_ <= 2 ) { # Two parameters
		my ($type, $descr) = @_;

		my $obj = { 'type' => $type };
		$obj->{'descr'} = $descr if defined $descr;

		return $obj;
	}
	else {
		@_ % 2 == 1  or fail "Неверное число аргументов";
		my ($type, %init) = @_;
		$init{'type'} = $type;
		return \%init;
	}
}

# Часто используемая операция - создание объекта типа текст.
sub make_text_obj($$@) {
	my ($type, $text, %other) = @_;

	my $obj = \%other;
	$obj->{'type'} = $type;
	$obj->{'text'} = $text;

	return $obj;
}

sub add_child($@) {
	my ($obj, @children) = @_;

	ref_push $obj->{'children'}, @children;
}

sub arrays_equal($$) {
	my ($arr1, $arr2) = @_;

	return 0 if @$arr1 != @$arr2; # сравниваем размеры

	for (my $i=0; defined $arr1->[$i]; $i++) {
		return 0 if $arr1->[$i] ne $arr2->[$i];
	}

	return 1; # одинаковы
}

sub is_array($) {
	return ref($_[0]) eq 'ARRAY';
}

#----------------------------------------------------------------------
1; # Return value
