package JDPrinterGTK;

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
use Carp;
use JDCommon;
use JD_AText;
use Gtk2;

#-----------------------------------------------------------------------

# Данные
my $dom;

# Хитрый символ, который выглядит как пробел, но не пробел.
# Используется как неразрывный (непереносимый) пробел.
my $nbsp = 160;

# Встроенная "светлая" схема
my %styles = (
	'no'            => {'foreground' => '#000000', 'family' => 'kochi,mincho'},
	'bold'          => {'foreground' => '#005000'},
	'comment'       => {'foreground' => '#000050'},
	'example'       => {'foreground' => '#500000'},
	'fd'            => {'foreground' => '#303030'},
	'footer'        => {'foreground' => '#303030'},
	'kun'           => {'foreground' => '#300040'},
	'kun_ref'       => {'foreground' => '#300040'},
	'kokuji'        => {'foreground' => '#500000'},
	'lat'           => {'foreground' => '#300040'},
	'main_kanji'    => {'foreground' => '#005000', 'scale' => 2},
	'marker_r'      => {'foreground' => '#500000'},
	'marker_g'      => {'foreground' => '#300040'},
	'message'       => {'foreground' => '#000050'},
	'names_1'       => {'foreground' => '#403000'},
	'names_header'  => {'foreground' => '#403000'},
	'notedited'     => {'foreground' => '#F03030'},
	'onyomi'        => {'foreground' => '#300040'},
	'particle'      => {'foreground' => '#005000'},
	'pref1'         => {'foreground' => '#000050'},
	'pref2'         => {'foreground' => '#303030'},
	'remark'        => {'foreground' => '#000050'},
	'rem_text'      => {'foreground' => '#303030'},
	'rusnick'       => {'foreground' => '#303030'},
	'strokes'       => {'foreground' => '#D0D0D0'},
	'transcr_cyan'  => {'foreground' => '#300040'},
	'transcr_red'   => {'foreground' => '#500000'},
	'tango_header'  => {'foreground' => '#403000'},
	'tan_title'     => {'foreground' => 'black'},
	'utility'       => {'foreground' => '#303030'},
	'kanji'         => {'scale' => 1.3},
	'kana'          => {'scale' => 1.2},
);

sub set_styles_map($) {
	my ($new_styles) = @_;

	%styles = %$new_styles;
}

sub Init($) {
	my ($text_view) = @_;

	my $text_buf = $text_view->get_buffer;

	local *pale;
	my $mul = 0.7;
	my $noc = Gtk2::Gdk::Color->parse($styles{'no'}{'foreground'});
	if ( $noc->red + $noc->green + $noc->blue < 65536*3/2 ) {
		# "светлая" схема
		*pale = sub {
			my ($c) = @_;
			return (65535 - (65535-$c)*$mul);
		};
	} else {
		# "тёмная" схема
		*pale = sub {
			my ($c) = @_;
			return $c*$mul;
		};
	}

	foreach my $tag ( keys %styles ) {
		next if $tag eq 'TYPE';
		$text_buf->create_tag($tag, %{$styles{$tag}});
		if ( $styles{$tag}{'foreground'} ) {
			my %properties = %{$styles{$tag}};
			# pale color
			my $fg = Gtk2::Gdk::Color->parse($properties{'foreground'});
			$fg = Gtk2::Gdk::Color->new(pale($fg->red), pale($fg->green), pale($fg->blue));
			$properties{'foreground'} = $fg->to_string;
			
			$text_buf->create_tag($tag."_pale", %properties);
		}
	}

	$text_buf->create_tag('italic', 'style' => 'italic');
}

# Вычисление реальной длины строки в терминале, т. е. с учётом "пустых"
# символов (цветовые коды) и широких символов (иероглифы и кана).
my $re_wide_symbols = qr/[　-〜ぁ-ヾ一-龥]/;
sub size {
	my ($txt) = @_;

	$txt = atext_tostr($txt);
	( $txt !~ /\e/ ) or fail;
	( $txt !~ /[\^#]/ ) or fail;

	my $res = length($txt);
	$res += ($txt =~ s/$re_wide_symbols//g); # возвращает количество замен

	return $res;
}

## "Main" function ##
sub article_to_atext {
	($dom) = @_; # NOT my, but global

	my $out = '';
	my $tmp = '';

	$out .= $dom->{'article_num'}.": ";

	$out .= object_to_atext( $dom->{'main_kanji'} );
	$out .= "  ";
	$out .= object_to_atext( $dom->{'rusnick'} );
	$out .= "  ";
	$out .= object_to_atext( $dom->{'strokes_num'} );
	$out .= "  ";
	$out .= object_to_atext( $dom->{'utility'} ) if $dom->{'utility'};
	$out .= "\n";

	$tmp = "   ".object_to_atext( $dom->{'onyomi'} );
	$tmp .= "   ".object_to_atext( $dom->{'remarks_glob'} );

	$out .= $tmp."\n\n" if $tmp ne '';

	# Kun table
	$tmp = object_to_atext( $dom->{'kun_table'} );

	$out .= $tmp."\n\n"  if $tmp ne '';

	if ( defined $dom->{'message'} ) {
		$out .= object_to_atext($dom->{'message'});
		$out .= "\n\n";
	}

	if ( defined $dom->{'tango'} ) {
		if ( defined $dom->{'tango_header'} ) {
			$out .= object_to_atext($dom->{'tango_header'})."\n\n";
		}

		$tmp = object_to_atext( $dom->{'tango'} );

		$out .= $tmp."\n\n"  if $tmp ne '';
	}

	if ( $dom->{'names'} || $dom->{'names_list'} ) {
		$out .= object_to_atext( $dom->{'names_header'} )."\n";

		if ( $dom->{'names_list'} ) {
			# "Центровка" надписи.
			$tmp = object_to_atext( $dom->{'names_list'} );
			my $sz = size ($tmp);
			if ( $sz < 17 ) {  $out .= " " x ( (17 - $sz) / 2 );  }
			$out .= " ".$tmp;
			$out .= "\n";
		}
		$out .= "\n";

		if ( $dom->{'names'} ) {
			$tmp = object_to_atext( $dom->{'names'} );

			$out .= $tmp."\n\n"  if $tmp ne '';
		}
	}

	if ( defined $dom->{'footer'} ) {
		$tmp = atext_colored('footer', $dom->{'footer'});

		$out .= object_to_atext($tmp)."\n" if $tmp ne '';
	}

	return $out;
}

sub object_to_atext {
	my ($obj) = @_;

	return '' if !defined $obj;

	my $res = '';

	my $ref = ref($obj);

	if ( $ref eq '' ) { # строка
		$res = $obj;
		$res =~ s/([　-〜ぁ-ヾ]+)/atext_colored('kana',$1)/ge;
	}
	elsif ( $ref eq 'HASH' ) { # объект
		my $type = $obj->{'type'} or fail "Invalid object";

		if ( $type eq 'vtable' ) {
			$res = vtable_to_atext($obj);
		}
		elsif ( $type eq 'htable' ) {
			$res = htable_to_atext($obj);
		}
		else {
			fail "Unknown object type: '$type'";
		}
	}
	else {
		fail "Unhandled reftype: '$ref'";
	}

	return $res;
}

sub object_pale {
	my ($obj) = @_;

	return if !defined $obj;

	my $ref = ref($obj);

	if ( $ref eq '' ) { # строка
		$_[0] = atext_pale($obj);
	}
	elsif ( $ref eq 'HASH' ) { # объект
		defined $obj->{'type'} or fail "Invalid object";

		my $type = $obj->{'type'};

		if ( $type eq 'vtable' || $type eq 'htable' ) {
			$_[0]->{'pale'} = 1;
		}
		else {
			fail "Unknown object type: '$type'";
		}
	}
	else {
		fail "Unhandled reftype: '$ref'";
	}
}

sub append_atext($$) {
	my ($text_view, $atxt) = @_;

	defined $atxt or fail;

	$atxt = atext_colored('no', $atxt);

	my $cstack = new_cstack();

	my $text_buf = $text_view->get_buffer;
	my $res = undef;

	my $atxt_orig = $atxt;

	while ($atxt ne '') {
		my $atxt_prev = $atxt;

		if ( $atxt =~ s/^([^#\^]+)//) { # обычный текст
			my $txt = $1;
			$text_buf->insert_with_tags_by_name($text_buf->get_end_iter, $txt);
			$res = 1;
		}
		elsif ( $atxt =~ s/^\^([^#\^]*)#// ) { # тэг
			my $tag = $1;

			if ( $tag =~ /^C([a-z1-9_]+)$/ ) { # начало стиля
				my $style = $1;
				if ( $style eq 'same' ) {
					$style = $cstack->{'styles'}[-1][1];
				}
				push_cstack($text_view, $cstack, $style);
			}
			elsif ( $tag =~ /^CX$/ ) { # конец стиля
				pop_cstack($text_view, $cstack, 'style');
			}
			elsif ( $tag =~ /^[PI]$/ ) { # pale or italic
				my $mod = undef;
				if ($tag eq 'P') { $mod = 'pale' }
				elsif ($tag eq 'I') { $mod = 'italic' }
				else { fail }

				push_cstack($text_view, $cstack, $mod);
			}
			elsif ( $tag =~ /^[PI]X$/ ) { # pale or italic OFF
				my $mod = undef;
				if ($tag eq 'PX') { $mod = 'pale' }
				elsif ($tag eq 'IX') { $mod = 'italic' }
				else { fail }

				pop_cstack($text_view, $cstack, $mod);
			}
			elsif ( $tag =~ /^K(\d{4})(.)$/ ) { # kanji
				my $id = $1;
				my $chr = $2;

				# TODO: здесь можно вставить ссылку на статью для кандзи

				$text_buf->insert_with_tags_by_name($text_buf->get_end_iter, $chr, 'kanji');
				$res = 1;
			}
			elsif ( $tag =~ /^T(\d{5})$/ ) { # tango block
				# TODO: здесь можно вставить ссылку на составное слово
			}
			elsif ( $tag =~ /^TX$/ ) { # tango block
				# TODO: здесь можно вставить ссылку на составное слово ^
			}
			else {
				fail "Unknown or wrong tag: '$tag'";
			}
		}

		$atxt ne $atxt_prev or fail "Inf loop: '$atxt'";
	}

	# Мог остаться незакрытый италик
	if ( @{$cstack->{'italic'}} ) {
		pop_cstack($text_view, $cstack, 'italic');
		errmsg "Warning! Non-closed italic.";
	}

	# Проверяем, что не осталось открытых цветов
	( !@{$cstack->{'styles'}} ) or fail;
	( !@{$cstack->{'pale'}} ) or fail;
	( !@{$cstack->{'italic'}} ) or fail;

	return $res;
}

# CStack

sub new_cstack() {
	return {'styles' =>[], 'pale' =>[], 'italic' =>[]};
}

sub push_cstack($$$) {
	my ($text_view, $cstack, $style) = @_;
	defined $cstack or fail;
	defined $style or fail;

	my $text_buf = $text_view->get_buffer;
	my $pos = $text_buf->get_char_count;

	if ( $style eq 'pale' ) {
		ref_push $cstack->{'pale'}, $pos;
	}
	elsif ( $style eq 'italic' ) {
		ref_push $cstack->{'italic'}, $pos;
	}
	else {
		( $styles{$style} ) or fail "Unknown style: '$style'";
		ref_push $cstack->{'styles'}, [$style, $pos];
	}
}

sub pop_cstack($$$) {
	my ($text_view, $cstack, $what) = @_;

	my $text_buf = $text_view->get_buffer;

	if ( $what eq 'style' ) {
		( @{$cstack->{'styles'}} )
			or fail "Style stack should be not empty";
		my ($style, $pos_start) = @{pop @{$cstack->{'styles'}}};
		if ( @{$cstack->{'pale'}} ) {
			$style = $style."_pale";
		}
		$text_buf->apply_tag_by_name($style, $text_buf->get_iter_at_offset($pos_start), $text_buf->get_end_iter);
	}
	elsif ( $what eq 'pale' ) {
		$cstack->{'pale'} > 0 or fail;
		if ( $cstack->{'pale'} > 0 ) {
			( @{$cstack->{'styles'}} )
				or fail "atext должен быть заключён в стиль 'no'";
			(my $style, undef) = @{$cstack->{'styles'}[-1]};
			$style = $style."_pale";
			my $pos_start = pop @{$cstack->{'pale'}};
			$text_buf->apply_tag_by_name($style, $text_buf->get_iter_at_offset($pos_start), $text_buf->get_end_iter);
		}
	}
	elsif ( $what eq 'italic' ) {
		# Может вызываться pop_cstack при пустом $cstack->{'italic'}, когда
		# происходит перевод строки.
		if ( @{$cstack->{'italic'}} ) {
			my $pos_start = pop @{$cstack->{'italic'}};
			$text_buf->apply_tag_by_name('italic', $text_buf->get_iter_at_offset($pos_start), $text_buf->get_end_iter);
		}
	}
}

sub vtable_to_atext {
	my ( $obj ) = @_;

	( defined $obj && ref($obj) eq 'HASH' ) or fail;

	( $obj->{'children'} && @{$obj->{'children'}} ) or return '';

	my $out = '';

	my $children = $obj->{'children'};
	my $N = @$children;
	for ( my $i = 0; $i < $N; $i++ ) {
		next unless defined  $children->[$i];

		# Разделяем блоки
		if ( $i > 0 ) {
			$out .= "\n";
			if ( defined $obj->{'spacing'} ) {
				$out .= "\n" x int($obj->{'spacing'}); # extra spacing
			}
		}

		if ( $obj->{'pale'} ) {
			object_pale( $children->[$i] );
		}

		$out .= object_to_atext( $children->[$i] );
	}

	return $out;
}

# horisontal table
sub htable_to_atext {
	my ($obj) = @_;

	if ( $obj->{'pale'} ) {
		object_pale( $obj->{'left'} );
		object_pale( $obj->{'right'} );
	}

	my $left_column = (object_to_atext($obj->{'left'}) or '');
	my @left_column = split /\n/, $left_column;
	my $left_column_width = max(map size($_), @left_column);

	my $right_column = (object_to_atext($obj->{'right'}) or '');
	my @right_column = split /\n/, $right_column;

	my $out = '';

	my $right_lines_num = @right_column;

	while ( @left_column > 0 || @right_column > 0 ) {
		my $left_line = (shift @left_column or '');
		my $right_line = (shift @right_column or '');

		$out .= $left_line;
		$out .= chr($nbsp) x ($left_column_width - size($left_line));
		$out .= chr($nbsp) x ($obj->{'spacing'} or 0); # разделитель
		$out .= $right_line;
		$out .= "\n" if (@left_column > 0 || @right_column > 0);
	}

	return $out;
}

1;
