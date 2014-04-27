package JD_AText;

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

# Export symbols
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(
	&atext_plain &atext_tostr
	&atext_italic &atext_italic_start &atext_italic_stop
	&atext_kanji &atext_tango
	&atext_pale &atext_colored
	&atext_lcfirst &atext_ucfirst &atext_upper
);

my $C_pale       = '^P#';
my $C_pale_off   = '^PX#';
my $C_italic     = '^I#';
my $C_italic_off = '^IX#';
my $C_off        = '^CX#';

sub atext_plain {
	my ($txt) = @_;

	$txt =~ /^[\w ,;:\.!\?\-\+=%\(\)\[\]\<\>""«»\/´'~]*$/
			or fail "Wrong symbols in plain text: '$txt'";

	return $txt;
}

sub atext_tostr {
	my ($txt) = @_;

	my $regexp_cl = "\\\^[CPIT][^\\#]*\\#";
	$txt =~ s/$regexp_cl//g;

	$regexp_cl = "\\\^K\\d{4}(.)\\#";
	$txt =~ s/$regexp_cl/$1/g;

	return $txt;
}

sub atext_pale {
	my ($txt) = @_;

	return $C_pale.$txt.$C_pale_off;
}

sub atext_italic_start() { return $C_italic }
sub atext_italic_stop() { return $C_italic_off }

sub atext_italic {
	my ($txt) = @_;

	atext_plain($txt); # Проверка

	return $C_italic . $txt . $C_italic_off;
}

sub atext_kanji {
	my ($kanji, $id) = @_;

	# ^K 1234 Ж #

	if ( defined $id ) {
		return '^K'.sprintf('%04d', int($id)).$kanji.'#';
	} else {
		return $kanji;
	}
}

sub atext_tango {
	my ($id, $text) = @_;

	# ^T 1234# text ^TX#

	return '^T'.sprintf('%05d', int($id)).'#'.$text.'^TX#';
}

sub C_color {
	my ($color) = @_;

	$color =~ /^[a-z1-9_]+$/ or fail "Bad color name";

	return '^C'.$color.'#';
}

sub atext_colored {
	my ($color, $txt) = @_;

	return $txt if $txt =~ /^\s*$/; # Не изменяем пустую строку.

	return C_color($color) . $txt . $C_off;
}

my $regexp_f = "((\\\^[^\\#]*\\#|[«»])*)([^\\\^«»])";

sub atext_lcfirst {
	my ($txt) = @_;

	defined $txt && ( ref($txt) eq '' ) or fail;

	$txt =~ s/^$regexp_f/$1\l$3/; # \l stands for lcfirst

	return $txt;
}

sub atext_ucfirst {
	my ($txt) = @_;

	defined $txt && ( ref($txt) eq '' ) or fail;

	$txt =~ s/^$regexp_f/$1\u$3/; # \u stands for ucfirst

	return $txt;
}
