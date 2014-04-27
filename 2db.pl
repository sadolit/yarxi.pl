#!/usr/bin/perl -W

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
use DBI;
use utf8;
use Carp;
use FindBin;

sub BEGIN {
	unshift @INC, $FindBin::Bin; # Search modules in the directory of this file
	$| = 1; # Don't buffer the output
}

#-----------------------------------------------------------------------

my ($jr_kan, $jr_tan, $jr_rad, $jr_str, $jr_ele);
my $db_filename = 'yarxi_u.db';

my $sqlite = 'sqlite3';
if ( system('which '.$sqlite) != 0 ) {
	$sqlite = 'sqlite';
	if ( system('which '.$sqlite) != 0 ) {
		die "'sqlite3' nor 'sqlite' command not found";
	}
}

my $temp_file = $db_filename.'.init';

# Parse parameters
my @args = @ARGV;
while ( @args ) {
	my $arg = shift @args;

	if ( $arg eq '--kan' ) {
		$jr_kan = shift @args or die "Expected jr_kan.utf8 after $arg";
	}
	elsif ( $arg eq '--tan' ) {
		$jr_tan = shift @args or die "Expected jr_tan.utf8 after $arg";
	}
	elsif ( $arg eq '--rad' ) {
		$jr_rad = shift @args or die "Expected jr_rad.utf8 after $arg";
	}
	elsif ( $arg eq '--str' ) {
		$jr_str = shift @args or die "Expected jr_str.txt after $arg";
	}
	elsif ( $arg eq '--ele' ) {
		$jr_ele = shift @args or die "Expected jr_ele.txt after $arg";
	}
	elsif ( $arg eq '--db' ) {
		$db_filename = shift @args or die "Expected database file name after $arg";
	}
	else {
		die "Unknown parameter '$arg'";
	}
}

if ( !$jr_kan && !$jr_tan && !$jr_rad && !$jr_str ) {
	print <<HEREDOC;
Usage: $0 [options]
	--kan jr_kan.utf8
	--tan jr_tan.utf8
	--rad jr_rad.utf8
	--str jr_str.txt
	--ele jr_ele.txt
HEREDOC
	exit;
}

my $dbi_path = "dbi:SQLite:dbname=${FindBin::Bin}/${db_filename}";
my $dbh = DBI->connect($dbi_path,"","");

#-----------------------------------------------------------------------

# Not used yet
sub snd_key {
	my ($snd) = @_;

	$snd =~ s/m([^aiueoy])/n$1/g;
	
	$snd =~ s/([aiueon])[:~]/$1/g;
	
	$snd =~ s/aa/a/g;
	$snd =~ s/oo/o/g;
	$snd =~ s/ou/o/g;
	
	$snd =~ s/ou/o/g;
	
	$snd =~ s/uu/u/g;
	
	$snd =~ s/ee/u/g;
	$snd =~ s/ii/i/g;
	$snd =~ s/iy/y/g;
		
	$snd =~ s/tt/t/g;
	$snd =~ s/dd/d/g;
	$snd =~ s/ss/s/g;
	$snd =~ s/zz/z/g;
	$snd =~ s/jj/j/g;
	$snd =~ s/kk/k/g;
	$snd =~ s/nn/n/g;
	$snd =~ s/nm/m/g;
	$snd =~ s/pp/p/g;
	$snd =~ s/ff/f/g;
	
	$snd =~ s/tch/ch/g;
	
	return $snd;
}
#----------------------------------------------------------------------

my @kan_fields = qw ( Nomer Str Utility Uncd Bushu RusNick Onyomi Kunyomi
		Russian Compounds Dicts Concise );
		
#----------------------------------------------------------------------

# Read jr_kan.utf8 and add its contents to the database.
sub process_kan {
	
	print "\n == jr_kan == \n";

	system("wc -l '$jr_kan'");

	my $table = 'Kanji';
	$dbh->do ("DROP TABLE IF EXISTS $table");
	
	my $sql_create = <<EOT;
CREATE TABLE $table (
	Nomer INTEGER PRIMARY KEY NOT NULL,
	Str integer NOT NULL DEFAULT 0,
	Utility integer NOT NULL DEFAULT 0,
	Uncd integer NOT NULL,
	Bushu varchar(1) NOT NULL,
	RusNick varchar(1) NOT NULL,
	Onyomi varchar(1) NOT NULL,
	Kunyomi varchar(1) NOT NULL,
	Russian varchar(1) NOT NULL,
	Compounds varchar(1) NOT NULL,
	Dicts varchar(1) NOT NULL,
	Concise varchar(1) NOT NULL
	);
EOT
	$dbh->do( $sql_create );

	$dbh->do ("CREATE INDEX UNCD_IDX ON $table(Uncd)" );

	open FILE, ">$temp_file" or die "Failed to write into '$temp_file'";

	my $fh;
	open $fh, $jr_kan;
	
	my $date = <$fh>; # The first line is date
	chomp($date);
	my $number = <$fh>; # The second line is the number of records
	chomp($number);

	my $start_time = time(); # Just to print some perfomance statistics

	my $nomer = 0;
	while (my $s = <$fh>) {
		chomp $s;
		utf8::decode($s);
		$s =~ s/\s+$//; # Trim left spaces
		
		next if ( $s eq '.' ); # dunno what means '.'
		
		my @arr = split('`', $s);

		my $first = shift @arr;
		my ( $strokes, $utility, $unicode, $bushu, $rusnick);
		if ( $first =~ /^(\d\d)(\d\d)(\d{5})([\d\/]*)(.*)$/ ) {
			$strokes = $1;
			$utility = $2;
			$unicode = $3;
			$bushu = $4;
			$rusnick = $5;
			
			my @bushu_spl = split('/', $bushu);
			$bushu = '*'.join('*', @bushu_spl).'*'; # It's handy to search by '*$bushu*' in such lines
		} else {
			print STDERR "Syntax wrong at line $.: first token: '$first'\n";
			next;
		}
		
		my $onyomi = (shift @arr or '');
		# onyomi должно выглядеть как '*aaa*bbb*ccc*ddd*' для удобства поиска
		# целых онъёми, но иногда первая или последняя звёздочка отсутствует,
		# потому что для Yarxi это не важно. А мы их таки добавим.
		$onyomi = '*'.$onyomi if ( $onyomi !~ /^\*/ );
		$onyomi = $onyomi.'*' if ( $onyomi !~ /\*$/ );
		
		my $kunyomi   = (shift @arr or '');
		my $russian   = (shift @arr or '');
		my $compounds = (shift @arr or '');
		my $dicts     = (shift @arr or '');
		my $concise   = (shift @arr or '');

		# Судя по всему, в базе ограничена длина поля kunyomi, поэтому в редких
		# случаях не влезающая часть его хранится в поле compounds.
		if ( $compounds =~ s/^_([^_]*)_// ) { # Переносится в начало кунъёми
			$kunyomi = $1.$kunyomi;
		}
		if ( $compounds =~ s/^_([^_]*)_// ) { # Если повторяется, то переносится в конец кунъёми.
			$kunyomi .= $1;
		}
		
		$nomer++;

		# Строка для вставки в базу данных
		my @add = ( $nomer, $strokes, $utility, $unicode, $bushu, $rusnick,
				$onyomi, $kunyomi, $russian, $compounds, $dicts, $concise );
		
		utf8::encode($_) for @add;
		
		print FILE join("\t", @add), "\n";
		
	}
	close $fh;

	close FILE;

	open PIPE, "| $sqlite '$db_filename'" or die "Failed to run $sqlite";
	print PIPE '.separator \t'."\n";
	print PIPE ".import $temp_file $table\n";
	close PIPE;
	system("rm '$temp_file'");

	# Analyze
	$dbh->do ("ANALYZE $table");
}
#----------------------------------------------------------------------

#======================================================================
#======================================================================

my @tan_fields = qw( Nomer K1 K2 K3 K4 Kana Reading Russian );

#----------------------------------------------------------------------

sub prepare_tan_sth {
	my ($N) = @_;

	my $sql_pv = "(?" . ( ", ?" x (@tan_fields - 1) ) . ")";

	my $sql = "INSERT INTO Tango (".( join ", ", @tan_fields ).")"
			." VALUES ".$sql_pv.";";

	my $sth = $dbh->prepare($sql) or die;
	
	return $sth;
}

sub insert_tan {
	my ($buf_ref, $sth) = @_;
	
	foreach ( @$buf_ref ) {
		( scalar(@$_) == scalar(@tan_fields) ) or die;
		$sth->execute( @$_ );
	}
}
#----------------------------------------------------------------------

sub process_tan {
	
	print "\n == jr_tan == \n";

	system("wc -l '$jr_tan'");

	my $table = 'Tango';
	$dbh->do ("DROP TABLE IF EXISTS $table");

	my $sql_create = <<EOT;
CREATE TABLE $table (
	Nomer INTEGER PRIMARY KEY NOT NULL,
	K1 integer NOT NULL DEFAULT 0,
	K2 integer NOT NULL DEFAULT 0,
	K3 integer NOT NULL DEFAULT 0,
	K4 integer NOT NULL DEFAULT 0,
	Kana varchar(1) NOT NULL,
	Reading varchar(1) NOT NULL,
	Russian varchar(1) NOT NULL
	);
EOT
	$dbh->do ($sql_create);

	open FILE, ">$temp_file" or die "Failed to write into '$temp_file'";

	my $fh;
	open $fh, $jr_tan;
	
	my $date = <$fh>; # The first line is date
	chomp($date);
	my $number = <$fh>; # The second line is the number of records
	chomp($number);

	my $start_time = time();

	my @buf = ();
	my $buf_max = 40;
	my $sth = prepare_tan_sth ( $buf_max );

	my $nomer = 0;
	while (my $s = <$fh>) {
		chomp $s;
		utf8::decode($s);
		$s =~ s/\s+$//; # Trim left spaces
		
		next if ( $s eq '.' );
		
		my @arr = split('`', $s);

		my $first = shift @arr;
		my @k = (0,0,0,0);
		my $i = 0;
		while ( $first =~ s/^(\d{4})// ) {
			$k[$i++] = $1;
		}
		if ( $first ne '' ) {
			print STDERR "Tan: Syntax wrong at line $,: first token: '$first'\n";
			next;
		}
		
		my $kana = (shift @arr or '');
		my $reading = (shift @arr or '');
		my $russian = (shift @arr or '');
		
		$nomer++;

		my @add = ( $nomer, @k[0..3], $kana, $reading, $russian );

		utf8::encode($_) for @add;
		
		print FILE join("\t", @add), "\n";
	}
	close $fh;

	close FILE;

	open PIPE, "| $sqlite '$db_filename'" or die "Failed to run $sqlite";
	print PIPE '.separator \t'."\n";
	print PIPE ".import $temp_file $table\n";
	close PIPE;
	system("rm '$temp_file'");
	
	# Analyze
	$dbh->do ("ANALYZE $table");
}
#----------------------------------------------------------------------

sub process_rad {
	print "\n == jr_rad == \n";

	system("wc -l '$jr_rad'");

	my $table = 'Radical';
	$dbh->do("DROP TABLE IF EXISTS $table");

	my $sql_create = <<EOT;
CREATE TABLE $table (
	Nomer INTEGER PRIMARY KEY NOT NULL,
	Uncd integer NOT NULL
	);
EOT
	$dbh->do($sql_create);

	open FILE, ">$temp_file" or die "Failed to write into '$temp_file'";

	my $rad = {};

	my $fh;
	open $fh, $jr_rad or die "Failed to open $jr_rad";
	while (my $line = <$fh> ) {
		utf8::decode($line);
		if ( $line =~ /^(\d+)\t(.)/ ) {
			my $nomer = int($1);
			my $chr = $2;

			print FILE join("|", $nomer, ord($chr)), "\n";

			$rad->{$nomer} = ord($chr);
		}
	}
	close $fh;

	close FILE;

	print "Import...\n";
	system("$sqlite '$db_filename' '.import $temp_file $table'"
		." && rm '$temp_file'");

	# Analyze
	$dbh->do ("ANALYZE $table");

	return $rad;
}
#----------------------------------------------------------------------

sub process_str {
	my ($rad) = @_;

	print "\n == jr_str == \n";

	system("wc -l '$jr_str'");

	my $table = 'Structure';
	#$dbh->do("DROP TABLE IF EXISTS $table");

	my $sql_create = <<EOT;
CREATE TABLE $table (
	KNomer INTEGER NOT NULL,
	R1 integer NOT NULL, R2 integer NOT NULL, R3 integer NOT NULL,
	R4 integer NOT NULL, R5 integer NOT NULL, R6 integer NOT NULL,
	R7 integer NOT NULL, R8 integer NOT NULL, R9 integer NOT NULL
	);
EOT
	#$dbh->do($sql_create);

	#$dbh->do ("CREATE INDEX STR_IDX ON $table(KNomer)" );

	my $sql;
	my $sth;
	
	#open FILE, ">$temp_file" or die "Failed to write into '$temp_file'";

	my @str = ();

	my $fh;
	open $fh, $jr_str or die "Failed to open $jr_str";
	my @R;
	while (my $line = <$fh> ) {
		$line =~ s/[\n\r]+$//;
		if ( $line =~ /^(\d{4})((?:\d{4})+)(A?)$/ ) {
			my $knomer = int($1);
			my $R = $2;
			#my $alt = ((defined $3 && $3 ne "") ? 1 : 0);
			@R = ($knomer);
			while ( $R =~ /(\d{4})/g ) {
				push @R, int($1);
			}
			push @str, [@R];
			while ( @R < 10 ) { push @R, 0; }
			#print FILE join( "|", @R ), "\n";
		} else {
			print "Skip line '$line'\n";
		}
	}
	close $fh;

	#close FILE;

	#print "Import...\n";
	#system("$sqlite '$db_filename' '.import $temp_file $table'"
		#." && rm '$temp_file'");

	#$dbh->do ("ANALYZE $table");

	print "\n == jr_ele == \n";
	system("wc -l '$jr_ele'");

	$table = 'Elements';
	#$dbh->do("DROP TABLE IF EXISTS $table");

	$sql_create = <<EOT;
CREATE TABLE $table (
	Radical INTEGER NOT NULL,
	R1 integer NOT NULL, R2 integer NOT NULL, R3 integer NOT NULL,
	R4 integer NOT NULL, R5 integer NOT NULL, R6 integer NOT NULL,
	R7 integer NOT NULL, R8 integer NOT NULL, Decomp integer NOT NULL
	);
EOT
	#$dbh->do($sql_create);

	#$dbh->do ("CREATE INDEX ELE_IDX ON $table(Radical)" );

	#open FILE, ">$temp_file" or die "Failed to write into '$temp_file'";

	my $ele = {};

	open $fh, $jr_ele or die "Failed to open '$jr_ele'";
	while (my $line = <$fh> ) {
		$line =~ s/[\n\r]+$//;
		if ( $line =~ /^(\d{4})((?:\d{4})+)(\d)(A?)$/ ) {
			my $nomer = int($1);
			my $R = $2;
			my $depth = $3;
			my $alt = ((defined $4 && $4 ne "") ? 1 : 0);
			if ( $R eq $1 ) { next; }
			@R = ($depth);
			while ( $R =~ /(\d{4})/g ) {
				push @R, int($1);
			}
			push @{$ele->{$nomer}}, [@R];
			shift @R;
			while ( @R < 8 ) { push @R, 0; }
			#print FILE join( "|", $nomer, @R, $depth ), "\n";
		} else {
			print "Skip line $line\n";
		}
	}
	close $fh;

	#close FILE;

	#print "Import...\n";
	#system("$sqlite '$db_filename' '.import $temp_file $table'"
		#." && rm '$temp_file'");

	#$dbh->do ("ANALYZE $table");

	print "\n == unfold == \n";

	my $mdepth = 4;
	my $cur_knomer;

	local *scan_mdepth = sub {
		my ($r) = @_;

		my $bs = $ele->{$r}; # варианты разбивки радикала $r
		if ( !$bs ) {
			if ( !$rad->{$r} ) { die "No radical $r in kanji $cur_knomer"; }
			# else
			return ($r); # Неразбиваемый радикал
		}
		my $res;
		foreach my $b ( @$bs ) { # варианты разбивки радикала $r
			if ( $b->[0] > $mdepth ) { # $b->[0] = depth
				my @tmp = ();
				foreach my $c ( @$b[1..$#$b] ) {
					push @tmp, &scan_mdepth($c);
				}
				if ( !$res || @$res < @tmp ) { # выбираем самое широкое разбиение
					$res = [@tmp];
				}
			} else {
				if ( !$res || @$res <= 1 ) {
					$res = [$r];
				}
			}
		}
		if ( !$res ) { return ($r); }
		return @$res;
	};

	local *calc_score = sub {
		my ($r, $score) = @_;
		if ( $score->{$r} ) { # Для этого радикала вес известен
			# Разделим его на составные радикалы
			my $bs = $ele->{$r}; # варианты разбивки радикала $r
			if ( $bs ) {
				foreach my $b ( @$bs ) { # варианты разбивки радикала $r
					# $b->[0] = depth
					my $subscore = int(($score->{$r} - 1)/(scalar(@$b)-1)) + 1; # делим поровну
					foreach my $c ( @$b[1..$#$b] ) { # составные радикалы
						unless ( $score->{$c} ) {
							$score->{$c} = $subscore;
							&calc_score($c, $score);
						}
					}
				}
			}
		} else {
			# Для этого радикала вес нужно сложить из составных радикалов
			my $bs = $ele->{$r}; # варианты разбивки радикала $r
			if ( !$bs ) {
				return 0; # так может произойти, если суммируется не максимальный вариант разбиения
			}
			foreach my $b ( @$bs ) { # варианты разбивки радикала $r
				my $sum = 0;
				foreach my $c ( @$b[1..$#$b] ) {
					my $csc = &calc_score($c, $score);
					if ( !$csc ) {
						$sum = 0;
						last;
					}
					$sum += $csc;
				}
				next if !$sum;
				if ( !$score->{$r} || $score->{$r} < $sum ) { # выбираем максимальную сумму
					$score->{$r} = $sum;
				}
			}
			if ( !$score->{$r} ) {
				return 0; # так может произойти, если суммируется не максимальный вариант разбиения
			}
			if ( @$bs > 1 ) {
				# Вызываем рекурсивно в случе, если есть более одного варианта разбиения,
				# чтобы расчитать веса для остальных ветвей
				&calc_score($r, $score);
			}
		}
		return $score->{$r};
	};

	$table = 'Unfolded';
	$dbh->do("DROP TABLE IF EXISTS $table");

	$sql_create = <<EOT;
CREATE TABLE $table (
	KNomer INTEGER NOT NULL,
	Radical INTEGER NOT NULL,
	Score INTEGER NOT NULL
	);
EOT
	$dbh->do($sql_create);

	open FILE, ">$temp_file" or die "Failed to write into '$temp_file'";

	local *scan_print = sub { # обходим дерево разбиения радикалов
		my ($knomer, $r, $score, $printed) = @_;
		return if $printed->{$r};
		($score->{$r}) or die "No score for $r in kanji $knomer";
		print FILE join("|", $knomer, $r, $score->{$r}), "\n";
		$printed->{$r} = 1;
		my $bs = $ele->{$r}; # варианты разбивки радикала $r
		if ( $bs ) {
			foreach my $b ( @$bs ) { # варианты разбивки радикала $r
				# $b->[0] = depth
				foreach my $c ( @$b[1..$#$b] ) { # составные радикалы
					&scan_print($knomer, $c, $score, $printed);
				}
			}
		}
	};

	foreach my $s ( @str ) { # Для каждого иероглифа
		my $knomer = $s->[0];
		$cur_knomer = $knomer; # для отладки
		# Разбиваем иероглиф на радикалы, у которых глубина разбиения <= $mdepth.
		# Если у радикала несколько вариантов разбиения, то выбирается то,
		# в котором больше всего составных частей.
		my %median = ();
		foreach my $r ( @$s[1..$#$s] ) { # R1, R2, R3
			foreach my $med ( &scan_mdepth($r) ) {
				$median{$med} = 1;
			}
		}
		# Этому разбиению сопоставляются веса 120/N, где N -
		# кол-во радикалов (округление вверх).
		my %score = ();
		foreach my $med ( keys %median ) {
			$score{$med} = int((120-1)/scalar(keys %median)) + 1;
		}
		# Затем расчитываем веса для всех остальных радикалов.
		foreach my $r ( @$s[1..$#$s] ) { # R1, R2, R3
			&calc_score($r, \%score) or die "Score 0 for $r in kanji $knomer";
		}
		my $printed = {};
		foreach my $r ( @$s[1..$#$s] ) { # R1, R2, R3
			&scan_print($knomer, $r, \%score, $printed);
		}
	}

	close FILE;

	print "Import...\n";
	system("$sqlite '$db_filename' '.import $temp_file $table'"
		." && rm '$temp_file'");

	$dbh->do ("ANALYZE $table");
}
#----------------------------------------------------------------------

# MAIN #

if ( $jr_kan) { process_kan(); }
if ( $jr_tan) { process_tan(); }

my $rad;
if ( $jr_rad) { $rad = process_rad(); }
if ( $jr_str || $jr_ele ) {
	( $jr_str && $jr_ele ) or die "Both --str and --ele should be specified";
	( $rad ) or die "--rad is also required for --str and --ele.";
	process_str($rad);
}

exit 0;
