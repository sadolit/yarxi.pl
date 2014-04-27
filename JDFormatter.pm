package JDFormatter;

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

# Export symbols
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(
	$kana_base @kana

	&format_article &kana &kiriji
	&format_tango_alone
);
#-----------------------------------------------------------------------

my $objects;
my $tan_objs;
my $dom;

my $global_num; # DBG:

my $cur_block;

my $cur_trans_type; # Вид транскрипции: romaji/kiriji/hiragana/katakana
my ($romaji_or_kiriji, $cur_trans_kana); # Часто используемые в коде условия.

sub set_cur_trans_type {
	($cur_trans_type) = @_;

	$romaji_or_kiriji = ($cur_trans_type eq 'romaji' || $cur_trans_type eq 'kiriji');
	$cur_trans_kana = ($cur_trans_type eq 'hiragana' || $cur_trans_type eq 'katakana');

	$romaji_or_kiriji || $cur_trans_kana
		or fail "Неверный cur_trans_type: '$cur_trans_type';"
				." Должен быть один из: romaji/kiriji/hiragana/katakana";
}
# Set defaults
set_cur_trans_type('kiriji');

# кодовые обозначения в словаре.
my %code_names = (
		'^0' => 'См.',
		'^1' => 'Ср.',
		#'^2' => '',
		'^3' => 'Реже',
		'^4' => 'Иначе',
		'^5' => 'Чаще',
		'^6' => 'Синоним',
		'^7' => 'Антоним',
		'^8' => 'Не путать с',
		'^9' => 'Ранее',

		'^^1' => 'сокр. от',
		'^^2' => 'то же, что',
		'^^3' => 'не смешивать с',

		'^o' => 'Часто заменяется на',
		'^i' => 'Иногда также',
		'^m' => 'Ошибочно вместо',
		'^r' => 'Ранее также',
		'^s' => 'Как сокращение',
		'^S' => 'Синоним и омоним:',
		'^t' => 'Теперь',
		'^v' => 'Как вариант знака',
		'^z' => 'Как замена',
		'^Z' => 'Редко, как замена',

		'*0' => 'Устаревшая форма:',
		'*1' => 'Оригинальная форма:',
		'*2' => 'Упрощённая форма:',
		'*3' => 'Вариантная форма:',
		'*4' => 'Редкая форма:',
		'*5' => 'В документах:',
		'*6' => 'Синоним и омоним:',
		'*7' => 'Ошибочная форма:',

		'$0' => 'Устаревшая форма знака',
		'$1' => 'Оригинальная форма знака',
		'$2' => 'Упрощённая форма знака',
		'$3' => 'Заменён знаком',
		'$4' => 'Вариант знака',
		'$5' => 'Редкая форма знака',
		'$6' => 'Употребляется ошибочно вместо',
		'$7' => 'Теперь чаще',
		'$8' => 'Ранее также',

		'^^' => 'Чаще хираганой',
		'^@' => 'Чаще катаканой',
		'^#' => 'Чаще каной',

		'*?' => 'Как-то связан, наверное: ',
	);

# Кодовые обозначения частиц, постфиксов и их сочетаний
my %particles = (
		'0' => 'shita',
		'1' => 'suru',
		'2' => 'na',
		'3' => 'no',
		'4' => 'ni',
		'5' => 'de',
		'6' => 'to',
		'7' => 'taru',
		'8' => 'shite',
		'9' => 'shite iru',

		'-' => '(-demo)',
		'-0' => '(-wa)',
		'-1' => '(-kara)',
		#'-2' => '(-made)???????',
		'-3' => '(-no)',
		'-4' => '(-ni)',
		#'-5' => '(-de)????????',
		'-6' => '(-to)',
		'-7' => '(-wo)',
		'-8' => '(-ga)',
		'-9' => '(-suru)',
		'-@' => '(-to shite)',
		#'-+' => '(-shita)????????',
		#'-=' => '(shite iru)??????',

		'=00' => '!',
		'=01' => 'aru',
		'=02' => 'atte',
		'=03' => 'ga nai',
		'=04' => 'ga atte',
		'=05' => 'ga shite aru',
		'=06' => 'ga suru',
		'=07' => 'de mo',
		'=08' => 'de wa',
		'=09' => 'de nai',
		'=10' => 'de (~ni)',
		'=11' => 'des ka?',
		'=12' => 'deshita',
		'=13' => 'de suru',
		'=14' => 'ka',
		'=15' => 'made mo',
		'=16' => 'mo nai',
		'=17' => '[mo] nai',
		'=18' => 'mo naku',
		'=19' => 'nagara',
		'=20' => 'nai',
		'=21' => 'na (~no)',
		'=22' => 'narazaru',
		'=23' => 'narazu',
		'=24' => 'na[ru]',
		'=25' => 'nasai',
		'=26' => 'nashi no',
		'=27' => 'naki',
		'=28' => 'naku',
		'=29' => 'ni (~wa)',
		'=30' => 'ni (~de)',
		'=31' => 'ni mo',
		'=32' => 'teki',
		'=33' => 'ni shite',
		'=34' => 'ni [shite]',
		'=35' => 'ni nai',
		'=36' => 'ni natte',
		'=37' => 'ni natte iru',
		'=38' => 'ni aru',
		'=39' => 'ni sareru',
		'=40' => 'ni iru',
		'=41' => 'ni naranai',
		'=42' => 'sarete',
		'=43' => '[ni] suru',
		'=44' => 'ni yaru',
		'=45' => '[no] aru',
		'=46' => 'no shita',
		'=47' => 'no shinai',
		'=48' => 'no suru',
		'=49' => 'wo',
		'=50' => '[wo] suru',
		'=51' => 'wo shite iru',
		'=52' => 'wo shita',
		'=53' => 'wo yaru',
		'=54' => 'saseru',
		'=55' => 'sareru',
		'=56' => 'shite aru',
		'=57' => 'su',
		'=58' => 'shimas',
		'=59' => 'shinai',
		'=60' => 'sezuni',
		'=61' => 'seru',
		'=62' => 'to naru',
		'=63' => 'to saseru',
		#'=64' => '???',
		'=65' => '[to] shita',
		'=66' => 'to [shite]',
		'=67' => 'to mo',
		'=68' => '[to] mo sureba',
		'=69' => 'to nareba',
		'=70' => 'to [naku]',
		'=71' => 'e',
		'=72' => 'sarate iru',
		'=73' => 'ga gotoshi',
		'=74' => 'da kara',
		'=75' => 'dake no',
		#'=76' => '???',
		'=77' => 'mono',
		'=78' => 'naru',
		'=79' => 'naraba',
		'=80' => 'naranu',
		'=81' => 'narashimeru',
		'=82' => 'ni [natte]',
		'=83' => 'o shinai',
		'=84' => 'wo shite',
		'=85' => 'shinagara',
		'=86' => 'subeki',
		'=87' => 'sureba',
		'=88' => 'shitemo',
		'=89' => 'to mo shinai',
		'=90' => 'yaru',
		'=91' => 'to natte',
		'=92' => 'suruna',
		'=93' => 'ni oite',

		'~0' => 'o suru',
		'~1' => 'ga aru',
		'~2' => 'no aru',
		'~3' => 'no nai',
		'~4' => 'de aru',
		'~5' => 'des', # TODO: check #42
		'~6' => 'da',
		'~7' => 'ni suru',
		'~8' => 'ni naru',
		'~9' => 'to shite',

		# OK
		'~~0' => 'naru',
		'~~1' => 'kara',
		'~~2' => 'made',
		'~~3' => 'mo',
		'~~4' => 'wa',
		'~~5' => 'to suru',
		'~~6' => 'yori',
		'~~7' => 'ga shite iru',
		'~~8' => 'to shita',
		'~~9' => 'to shite iru',
	);

# кодовые обозначения сокращений
my %abbreviations = ( # @N
		'@0' => 'устар.', # В ориг. "уст."
		'@1' => 'прям. и перен.',
		'@2' => 'перен.',
		'@3' => 'и т.п.',
		'@4' => 'разг.',
		'@5' => 'прост.',
		'@6' => 'то же',
		'@7' => 'кн.',
		'@8' => '(в идиомах)',
		'@9' => 'арх.',

		'@@' => 'возвыш.',

		#'>>' => '', # В танго: '>>' - Имя собственное. Не отображается. Используется при поиске в фонетическом словаре, если отключена установка "Включая имена".
		'>1' => 'мужское имя',
		'>11' => 'мужские имена',
		'>12' => 'мужское либо женское имя',
		'>13' => 'мужское имя либо фамилия',
		'>2' => 'женское имя',
		'>21' => 'женское либо мужское имя',
		'>22' => 'женские имена',
		'>23' => 'женское имя либо фамилия',
		'>3' => 'фамилия',
		'>30' => 'имя либо фамилия',
		'>33' => 'фамилии',
		'>35' => 'фамилия и топоним',
		'>4' => 'псевдоним',
		'>5' => 'топоним',
		'>50' => 'имя либо топоним',
		'>55' => 'топонимы',
		'>53' => 'фамилии и топонимы',
	);

# Кодовые обозначения в заголовках в разделе составных слов.
my %tan_title_abbrevs = ( # @N in tango titles
		'@0' => 'употребляется фонетически',
		'@1' => 'сочетания неупотребительны',
		'@2' => 'сочетания малоупотребительны',
		'@3' => '<непродуктивно>',
		'@4' => 'в сочетаниях непродуктивен',
		'@5' => 'встречается в географических названиях',
		'@6' => 'в сочетаниях то же',
		'@7' => 'употребляется в единственном сочетании',
		'@8' => 'в сочетаниях идиоматичен',
		'@9' => '<также счётный суффикс>',

		'@L' => 'употребляется в летоисчислении',
		'@@' => 'встречается в именах',
	);

my %utility = (
		'1'  => "Гакусю: (1)",
		'2'  => "Гакусю: (2)",
		'3'  => "Гакусю: (3)",
		'4'  => "Гакусю: (4)",
		'5'  => "Гакусю: (5)",
		'6'  => "Гакусю: (6)",
		'7'  => "Дзё:ё: (7)",
		'8'  => "Дзё:ё: (8)",
		'9'  => "Дзё:ё: (9)",
		'10' => "Дзё:ё: (10)",
		'11' => "+++",
		'12' => "++",
		'13' => "+",
		'14' => "(++)",
		'15' => "(+)",
		'16' => "И++",
		'17' => "И+",
		'18' => "+/x",
		'19' => "x",
		'20' => "xx",
		'21' => "xxx",

		# 31..50 => 'Ф', # Устанавливается отдельно ниже

		'55' => "Радикал",
		'60' => "", # Пусто
	);

$utility{$_} = "Ф" for (31..50);
# http://www.susi.ru/yarxi/version5.html
# Новое в Яркси 5.0:
# "Группа Ф (формы и варианты) теперь имеет дополнительную внутреннюю градуировку,
# отражающую употребимость оригинальных знаков для форм и вариантов.
# Эта градуировка не видна пользователю, но учитывается при поиске и выводе данных.
# Так, например, если в поле поиска включена группа Ф, но не включены неупотребимые
# группы (x, xx, xxx), то среди результатов поиска не будет форм и вариантов знаков
# из неупотребимых групп."


# С этого значения начинаются символы каны. Они перечислены ниже
# в массиве @kana по порядку UTF-8 относительно $kana_base.
our $kana_base = 0x3041;

# Символы каны в UTF-8 относительно $kana_base. Подчёркивания обозначают
# уменьшенный вариант буквы. Заглавные буквы обозначают катакану.
# Знаки вопроса обозначают какие-то типографские значки, расположенные
# между катаканой и хираганой.
our @kana = qw/
		a_  a   i_  i     u_  u   e_  e   o_  o
		ka  ga  ki  gi    ku  gu  ke  ge  ko  go
		sa  za  shi ji    su  zu  se  ze  so  zo
		ta  da  chi di t_ tsu du  te  de  to  do
		na   ni   nu   ne   no
		ha ba pa hi bi pi fu bu pu he be pe ho bo po
		ma   mi   mu   me    mo
		ya_  ya   yu_  yu   yo_  yo
		ra   ri   ru   re    ro
		wa_  wa  y  ye  wo  n
		? ? ? ? ? ? ? ? ? ? ? ? ?
		A_  A   I_  I   U_  U   E_  E   O_  O
		KA  GA  KI  GI  KU  GU  KE  GE  KO  GO
		SA  ZA  SHI JI  SU  ZU  SE  ZE  SO  ZO
		TA  DA  CHI DI T_ TSU DU TE DE  TO  DO
		NA  NI  NU  NE  NO
		HA BA PA HI BI PI FU BU PU HE BE PE HO BO PO
		MA  MI  MU  ME  MO
		YA_  YA  YU_  YU  YO_  YO
		RA   RI   RU   RE   RO
		WA_  WA   Y    YE   WO   N
		V  KA_  qe
	/;

# Русская транскрипция получается простой транслитерацией (ki->ки)
# массива @kana плюс следующие правила из %tr_rus:
our %tr_rus = (
		'ii' => 'и', 'i!' => 'й', 'va' => 'ва',
		'shi' => 'си', 'sha' => 'ся', 'shu' => 'сю', 'sho' => 'сё',
		'chi' => 'ти', 'tsu' => 'цу', 'cha' => 'тя', 'chu' => 'тю', 'cho' => 'тё',
		'wa' => 'ва', 'wo' => 'о',
		"n'" => 'нъ',
		'za' => 'дза', 'zu' => 'дзу', 'ze' => 'дзэ', 'zo' => 'дзо',
		'ji' => 'дзи', 'ja' => 'дзя', 'ju' => 'дзю', 'jo' => 'дзё',
		'du' => 'дзу', 'di' => 'дзи',
	);

# Инвертируем массив каны, чтобы получить мэппинг ромадзи -> символ каны.
my %kana;
my $i = $kana_base;
foreach ( @kana ) {
	$kana{$_} = chr($i) if ( !defined $kana{$_} );
	$i++;
}

# дополнительные символы
my $kana_tiret = chr(12540); # Японская "тильда"

# Символы с апострофом, обозначающим мягкость
$kana{"n'"} = $kana{'n'};
$kana{"N'"} = $kana{'N'};

# показатель родительного(?) падежа ha, читающийся (в этом случае)
# как va (не путать с wa). (мои обозначения)
$kana{'va'} = $kana{'ha'};
$kana{'VA'} = $kana{'HA'};

# i, которое в этом случае читается как й (мои обозначения)
$kana{'i!'} = $kana{'i'};
$kana{'I!'} = $kana{'I'};

# Непротяжённый символ юникода
my $nw_over = chr(772);

# Русские кавычки-ёлочки.
my $laquo = chr(171);
my $raquo = chr(187);

# символ ударения.
my $stress_mark = chr(180); #chr(769);

# Получение каны через промежуточный "универсальный формат"
sub kana {
	my ($kana, $type) = @_;
	# Параметр $type нужен для того, чтобы понять, какую кану использовать
	# в сложных случаях (вроде ":").

	my $arr;

	if ( ref($kana) eq 'HASH' ) {
		if ( !defined $type && defined $kana->{'type'} ) {
			$type = $kana->{'type'};
		}
	}
	elsif ( ref($kana) eq '' ) { # just text
		$kana = parse_kana($kana);
	}
	else { fail }

	$arr = $kana->{'children'};

	my $res = '';

	my $N = @$arr;
	for (my $i = 0; $i < $N; $i++ ) {
		my $s = $arr->[$i];

		my $is_katakana = 0;
		$is_katakana = 1 if ( defined $type && $type eq 'katakana' );
		$is_katakana = 1 if ( !$type && $s =~ /^[A-Z]/ );

		if ( $s =~ /^t_$/i ) { # маленькое цу
			# Удвоение согласной
			if ( defined $arr->[$i+1] ) {
				$arr->[$i+1] =~ /^[\)kstfpcdgjzbh]/i or fail $arr->[$i+1];
			}
			$res .= get_kana($s);
		}
		elsif ( $s =~ /^([knhmrgbpd])(y[auo])$/i ) {
			if ( $is_katakana ) {
				$res .= get_kana($1.'I');
			} else {
				$res .= get_kana($1.'i');
			}
			$res .= get_kana($2.'_');
		}
		elsif ( $s =~ /^(sh|ch|j)([auo])$/i ) {
			if ( $is_katakana ) {
				$res .= get_kana($1.'I');
				$res .= get_kana('Y'.$2.'_');
			} else {
				$res .= get_kana($1.'i');
				$res .= get_kana('y'.$2.'_');
			}
		}
		elsif ( $s =~ /^(f)([aeio]|y[u])$/i ) {
			if ( $is_katakana ) {
				$res .= get_kana($1.'U');
				$res .= get_kana($2.'_');
			} else {
				$res .= get_kana($1.'u');
				$res .= get_kana($2.'_');
			}
		}
		elsif ( $s =~ /^(t)(i|yu)$/i ) {
			if ( $is_katakana ) {
				$res .= get_kana('TE');
				$res .= get_kana($2.'_');
			} else {
				$res .= get_kana('te');
				$res .= get_kana($2.'_');
			}
		}
		elsif ( $s =~ /^(j|ch|sh)(e)$/i ) {
			if ( $is_katakana ) {
				$res .= get_kana($1.'I');
				$res .= get_kana($2.'_');
			} else {
				$res .= get_kana($1.'i');
				$res .= get_kana($2.'_');
			}
		}
		elsif ( $s =~ /^(w)([ei])$/i ) {
			if ( $is_katakana ) {
				$res .= get_kana('U');
				$res .= get_kana($2.'_');
			} else {
				$res .= get_kana('u');
				$res .= get_kana($2.'_');
			}
		}
		elsif ( $s =~ /^(V)(Y?[IUEO])$/ ) {
			if ( $is_katakana ) {
				$res .= get_kana($1);
				$res .= get_kana($2.'_');
			} else {
				fail $s;
			}
		}
		elsif ( $s =~ /^(HU)$/ ) {
			if ( $is_katakana ) {
				$res .= get_kana('FU');
			}
		}
		elsif ( $s =~ /^(tu)$/i ) {
			if ( $is_katakana ) {
				$res .= get_kana('TSU');
			} else {
				fail $s;
			}
		}
		elsif ( $s =~ /^(tso)$/i ) {
			if ( $is_katakana ) {
				$res .= get_kana('TSU');
				$res .= get_kana('O_');
			} else {
				fail $s;
			}
		}
		elsif ( $s =~ /^:$/i ) {
			if ( !defined $type ) {
				$i > 0 || defined $type or fail; # 1093
				$arr->[$i-1] =~ /^[A-Za-z]/ or fail;
				$is_katakana = 1 if $arr->[$i-1] =~ /^[A-Z]/;
			}
			if ( $is_katakana ) {
				$res .= $kana_tiret;
			} else {
				$res .= get_kana('u');
			}
		}
		elsif ( $s =~ /^s_$/i ) {
			if ( $is_katakana ) {
				$res .= get_kana('SU');
			} else {
				$res .= get_kana('su');
			}
		}
		elsif ( $s =~ /^SI$/ ) {
			if ( $is_katakana ) {
				$res .= get_kana('SHI');
			} else {
				fail $s;
			}
		}
		elsif ( $s =~ /^( |-)$/ ) {
			# Не добавляем в кану пробелы и дефисы
		}
		elsif ( $s =~ /^\?$/ ) {
			# Я понавставлял "?" в таблицу @kana, поэтому их
			# приходится отлавливать отдельно.

			#$res .= "?"; # А всё равно их не надо отображать
		}
		elsif ( $s =~ /^(i)i$/i ) {
			# Тоже моё обозначение долгой i
			$res .= get_kana($1);
		}
		else {
			if ( defined $kana{$s} ) {
				$res .= $kana{$s};
			} else {
				# Не содержит букв и других символов, которые должны быть распарсены
				$s !~ /[a-zA-Zа-яёЁА-Я:_ ]/ or fail $s;

				$res .= $s;
			}
		}
	}

	return $res;
}

sub get_kana {
	my ($txt) = @_;
	defined $kana{$txt} or fail "kana_sub: undefined: $txt";
	return $kana{$txt};
}

sub kiriji {
	my ($txt) = @_;

	$txt or fail;
	ref($txt) eq '' or fail;

	my $arr = parse_kana(lc $txt);

	defined $arr->{'children'} && @{$arr->{'children'}} or fail;

	return kiriji_sub($arr->{'children'});
}

sub kiriji_sub {
	my ($arr) = @_;

	my $res = '';

	my $N = @$arr;
	for (my $i = 0; $i < $N; $i++ ) {
		my $s = $arr->[$i];

		if ( $s eq 't_' ) {
			# Удвоение согласной
			my $n = $arr->[$i+1];
			if ( $n =~ /^(\))$/ ) {
				$n = $arr->[$i+2];
			}
			defined $n or fail;
			if ( $n =~ /^([kstpcfdgjzbh])/ ) {
				my $t = $1;
				$t =~ tr[kstpcfdgjzbh]
				        [кстптфдгддбх];
				$res .= $t; next;
			}
			else { fail "@$arr"; }
		}
		elsif ( $s eq 'n' && $i < $N-1 ) {
			my $n = $arr->[$i + 1];

			if ( $n =~ /^[aiueo]/ ) {
				# ん («н») перед гласными пишется как «нъ» во избежание
				# путаницы со слогами ряда «на»
				$res .= 'нъ'; next;
			}
			elsif ( $n =~ /^[mbp]/ ) {
				# ん («н») перед «б» «п» и «м» записывается как «м»
				$res .= 'м'; next;
			}
		}
		elsif ( $s eq 'i' ) {
			if ( $i < $N-1 && $arr->[$i + 1] =~ /^[i]/ ) { # каваий
				$res .= 'и';
				next;
			}
			if ( $i > 0 ) {
				my $p = $arr->[$i - 1];

				if ( $p =~ /[aueo]$/ ) {
					#errmsg ( "й");
					$res .= 'й'; next;
				}
				elsif ( $p =~ /[i]$/ ) {
					if ( $i < $N-1 && $arr->[$i + 1] !~ /^[aiueo]/ ) {
						$res .= 'и'; next;
					} else {
						$res .= 'й'; next;
					}
				}
			}
		}
		elsif ( $s eq 's_' ) {
			$res .= 'с'; next;
		}
		elsif ( $s eq 'che' ) {
			$res .= 'чэ'; next;
		}
		elsif ( $s eq 'she' ) {
			$res .= 'се'; next;
		}

		#elsif ( $s eq ':' && $res =~ /[ауэояюёАУЭОЯЮЁ]$/ ) {
			#$res .= $nw_over;
			#next;
		#}
		# TODO: check /[^auo]:/; 'e:' ???

		# TODO: s/oo/o:/ или о с чёрточкой

		# Else

		if ( defined $tr_rus{$s} ) {
			$s = $tr_rus{$s};
		}
		else {
			$s =~ s/ya/я/ or
			$s =~ s/yu/ю/ or
			$s =~ s/yo/ё/;

			$s =~ tr[kgnmbprsztdhfwaiueojv]
			        [кгнмбпрсзтдхфваиуэожв];

			$s !~ /[a-zA-Z]/  # Не содержит нераспарсенных символов.
				or fail "'$s' in '@$arr'";
		}
		$res .= $s;
	}

	return $res;
}

sub cur_trans {
	my ($text) = @_;

	ref($text) eq '' or fail;

	if ( $cur_trans_type eq 'romaji' ) {
		$text =~ s/:/$nw_over/eg;
		return $text;
	}
	elsif ( $cur_trans_type eq 'kiriji' ) {
		return kiriji($text);
	}
	elsif ( $cur_trans_type eq 'hiragana' ) {
		return kana(lc $text, "");
	}
	elsif ( $cur_trans_type eq 'katakana' ) {
		return kana(uc $text, "");
	}

	fail;
}
#----------------------------------------------------------------------

# Возвращает atext_kanji по номеру статьи
sub make_kanji($) {
	my ($id) = @_;
	$id =~ s/^0+//; # убираем нули из начала, чтобы проверить, что это число.
	$id eq int($id) or fail;
	my $row = fetch_kanji_full($id);
	return atext_kanji( chr( $row->{'Uncd'} ), $id );
}
#----------------------------------------------------------------------

# Составное слово
sub make_tango {
	my ($tango_id, $add_reading) = @_;
	defined $tango_id or fail;

	my $row = fetch_tango_full($tango_id);
	$row or fail "No such record in the database: Tango $tango_id";

	my $tan_obj = parse_tan_simple( $row );
	defined $tan_obj->{'word'} or fail;

	my $text = $tan_obj->{'word'};

	if ( $add_reading ) {
		defined $tan_obj->{'readings'}->[0] or fail "No readings in tango '$tango_id'";

		for my $reading ( @{$tan_obj->{'readings'}} ) {
			defined $reading->{'text'} or fail;
			$reading->{'type'} eq 'reading' or fail;
			# Check: 218 - 仮

			my $reading_text = "[" . cur_trans( $reading->{'text'} ) . "]";
			$reading_text = atext_pale($reading_text) if $reading->{'pale'};
			$text .= " ".$reading_text;
		}
	}

	return atext_tango($tango_id, $text);
}
#----------------------------------------------------------------------

## Главная функция ##

# Возвращает дерево $dom с форматированной статьёй.
sub format_article {
	my ($num) = @_;
	$num eq int($num) or fail;
	$global_num = $num;

	# Берём данные из базы
	my $row = fetch_kanji_full($num);
	return undef if !$row; # Нет такой статьи

	#
	$objects = new_dom_object('objects', 'All the article data');
	$dom = new_dom_object('dom', 'Document tree');

	$objects->{'main_kanji'}  = $row->{'Nomer'};
	$objects->{'article_num'} = $row->{'Nomer'};

	# $objects->{'bushu'} = $row->{'Bushu'}; # Not used yet
	# parse_concise ( $row->{'Concise'} ); # Not used yet
	# parse_dicts ( $row->{'Dicts'} );     # Not used yet

	$dom->{'utility'} = format_utility( $row->{'Utility'} );

	# Article num
	$dom->{'article_num'} = $objects->{'article_num'};

	# Strokes number
	$dom->{'strokes_num'} = format_strokes( $row->{'Str'} );

	# Main kanji
	my $main_kanji = make_kanji( $objects->{'main_kanji'} );
	$dom->{'main_kanji'} = atext_colored( 'main_kanji', $main_kanji );

	# RusNick
	$dom->{'rusnick'} = format_rusnick( $row->{'RusNick'} );
	# Onyomi
	$dom->{'onyomi'} = format_onyomi( $row->{'Onyomi'} );


	$cur_block = 'Kanji';
	### Kunyomi ###
	parse_kunyomi( $row->{'Kunyomi'} );


	### Russian ###
	parse_kan_russian( $row->{'Russian'} );



	$dom->{'kun_table'} = format_kun_table( $objects->{'kuns'}, $objects->{'kuns_rus'} );

	# Compounds
	$objects->{'compound_defs'} = parse_compounds( $row->{'Compounds'} );


	## Второй блок - составные слова
	$cur_block = 'Tango';
	if ( defined $objects->{'tango_titles'} ) {

		if ( $objects->{'tango_header_replace'} ) {
			$objects->{'tango_titles'}->[0] or fail;
			my $newhead = $objects->{'tango_titles'}->[0]; # #40 - 鞍
			$newhead = parse_tango_title( $newhead, 'no_abbr_italic' );
			$newhead = atext_ucfirst( $newhead );
			$newhead = atext_colored( 'tango_header', $newhead );
			$dom->{'tango_header'} = $newhead;
		}
		else {
			$dom->{'tango_header'} = "  ".atext_colored('tango_header', '== В сочетаниях: ==');
		}
	}

	if ( defined $objects->{'tango_titles'} || $objects->{'compound_defs'}{1} ) {
		$dom->{'tango'} = format_tango( $objects->{'compound_defs'} );
	}

	## Имена
	$cur_block = 'Names';

	$dom->{'names_header'} = atext_colored('names_header', "  == В именах: ==");

	if ( $objects->{'names_kuns'} ) {
		$dom->{'names_list'} = format_names_list( $objects->{'names_kuns'} );
	}

	if ( defined $objects->{'compound_defs'}{'N'} ) { #12 - 穐
		$dom->{'names'} = format_names( $objects->{'compound_defs'} );
	}

	return $dom;
}
#----------------------------------------------------------------------

# Разбор поля Kunyomi в таблице Kanji.
sub parse_kunyomi {
	my ($line) = @_;

	# e.g. Kunyomi: 40*omommiru*!R *kore*^40941-"re"^42185-" "^41511*
	#        ||$kore$|$i$|$tada$nobu$yoshi$-$tamotsu$;

	# Разделяем по вертикальной черте |
	my @line_split = split /\|/, $line;

	my $kunyomi = (shift @line_split or "");

	#  Первая часть: кол-во букв, заменяемых иероглифом
	my $first_chunk = "";
	# Разбираем первый кусок (kanjisize)
	if ( $kunyomi =~ s/^([^\*]*)(\*|$)/$2/ ) { # Отделяем первый кусок - всё до *
		parse_kun_first_chunk( $1 ); # Разбор первого куска (kanjisize)
	}

	# Разбираем все куны
	$objects->{'kuns'} = parse_kun_main($kunyomi);

	# Куны в заголовках танго.
	my $tango_kuns_chunk = (shift @line_split or "");
	parse_tango_kuns($tango_kuns_chunk);

	# Куны для блока имён иногда отделены одной чертой |, а иногда двумя ||
	shift @line_split if( defined $line_split[0] && $line_split[0] eq "" );

	$objects->{'names_kuns'} = parse_names_kuns( @line_split );
}
#----------------------------------------------------------------------

# Разбор начала kunyomi - определение kanjisize
sub parse_kun_first_chunk($$) {
	my ($first_chunk) = @_;

	# Формат:  (!\d[!?])?\d+
	#   !2! означает, что будут показаны 2 куна, а остальное под кат (надо скроллить).
	#   !2? - ???
	#   \d+ - одна цифра на каждый кун - количество символов каны, заменяемых иероглифом.
	#   ^4 означает 14.
	#   (0 когда нет каны после иероглифа).

	$first_chunk =~ /^(!\d\d?[!\?])?[\d\^_]*$/ or fail;

	if ( $first_chunk =~ s/^!(\d\d?)([!\?])// ) {
		# Пока не используется
		# $objects->{'cut_height'} = $1;
		# $objects->{'cut_what'} = $2; # '!' означает показывать не все куны; '?' - не все танго.
	}

	my $i = 0;

	while ( $first_chunk ne "" ) {
		my $first_chunk_prev = $first_chunk;

		if ( $first_chunk =~ s/^(\^?\d)// ) {  # ^4 означает 14
			my $size = $1;
			$size =~ s/^\^/1/;

			$objects->{'kanjisize'}->[$i] = $size; # записываем kanjisize.
			$i++;
		}
		elsif ( $first_chunk =~ s/^_// ) {
			$first_chunk !~ /^_/ # Два подчёркивания _ подряд не должно быть.
				or fail;
			# Свёртка?
			# Пока не используется
		}

		$first_chunk ne $first_chunk_prev or fail "First chunk: Inf loop: '$first_chunk'";
	}
}
#----------------------------------------------------------------------

# Разбор продолжения Kunyomi - сами куны
sub parse_kun_main {
	my ($kunyomi) = @_;

	# ** означают бледный цвет и должны идти перед словом
	$kunyomi !~ /\*\*[^a-z ]/ or fail;

	# Небольшое переформатирование
	# Убираем пробелы перед кунами, записанными катаканой
	$kunyomi =~ s/(^|\*) +([A-Z])/$1$2/g;

	# Убираем пробелы и после.
	$kunyomi =~ s/ +\*/\*/g;

	# Заменяем "**word*" на "*word_*". Я хочу применять цвет к готовому слову.
	$kunyomi =~ s/\*\*([^\*]+)/*$1_/g;

	## Заменяем "*/*word" на */word" чтобы на этом месте не обрывалась цепочка.
	$kunyomi =~ s/\*([\/=&])\*/\*$1/g;

	# Добавляем символ ! перед кодовыми обозначениями, чтобы не перепутать их со словами.
	$kunyomi =~ s/\*(V[TI2]|Q[1237]|L1)(?=\*|$)/\*!$1/g;

	# Fix: Иногда ссылки не отделены звёздочкой (862: *hiroi^50859*).
	$kunyomi =~ s/([a-z:])\^/$1*^/g; # Заменяем ^ перед которой буква на *^.
	#

	$kunyomi =~ s/^\*+//; # Убираем все звёздочки * в начале
	$kunyomi =~ s/\*+$//; # Убираем все звёздочки * в конце строки

	my @kunyomi_spl1 = split(/\*/, $kunyomi); # Разделяем по звёздочке *

	my @kun_chains = (); # массив для результатов
	my @kun_arr = (); # Массив для текущей цепочки

	while ( @kunyomi_spl1 ) {
		my $chunk = shift @kunyomi_spl1; # берём очередной элемент

		if ( $chunk =~ /^[a-zA-Z]/ ) {  # Если начинается с буквы
		# Это новый кун!

			# Сначала сохраним предыдущую цепочку, если есть
			push @kun_chains, [@kun_arr] if @kun_arr;  # Сохраняем копию цепочки в массиве результатов

			@kun_arr = ($chunk); # Начинаем новую цепочку

			next;
		}

		push @kun_arr, $chunk; # Добавляем новый элемент к цепочке
	}
	# последняя цепочка осталась несохранённой
	push @kun_chains, [@kun_arr] if @kun_arr;  # Сохраняем копию цепочки в массиве результатов

	my @kuns = ();

	# А теперь разбираем каждую цепочку.
	my $kun_n = 0;
	foreach my $kun_chain ( @kun_chains ) {
		my $tmp_kun = parse_kun_chain($kun_chain, $kun_n);
		$kun_n++;

		push @kuns, $tmp_kun;
	}

	return \@kuns;
}

# Разбор выделенной цепочки кунов
sub parse_kun_chain {
	my ($kun_chain, $kun_n) = @_;

	my $kun = new_dom_object('kun'); # объект-результат

	@$kun_chain or fail 'Empty kun chain.';

	# бледное, если первое слово оканчивается подчёркиванием
	my $main_word = $kun_chain->[0];
	$kun->{'pale'} = ( $main_word =~ s/_$// );

	$main_word =~ /^[a-zA-Z:][a-zA-Z:\(\)' \-]*$/
		or fail "Wrong main word '$main_word'";

	$kun->{'main'} = $main_word;
	$kun->{'descr'} = $main_word; # DBG: для отладки

	$kun->{'kanjisize'} = ( $objects->{'kanjisize'}->[$kun_n] || length $main_word ); # до format_word!

	my $ins_shift = 0; # Сдвиг при вставке нескольких символов по очереди.
	my $ins_pos_prev = 0; # Контролируем, что позиция вставки только увеличивается

	my $word_ins_shift = -$kun->{'pale'}; # Сдвиг при вставке в основное слово. Обусловлен **.
	my $word_ins_pos_prev = 0; # Контролируем, что позиция вставки только увеличивается

	my $last_transcr; # ссылка на последнюю добавленную транскрипцию

	my $rem_prev = undef;

	foreach  my $chunk ( @$kun_chain ) {
		my $chunk_orig = $chunk; # Для отладочной печати при ошибках

		while ( $chunk !~ /^\s*$/ ) {
			my $chunk_prev = $chunk;

			$rem_prev = undef if $chunk !~ /^\^/;

			if ( $chunk =~ s/^\/?([a-zA-Z:][a-zA-Z \(\)'\-:]*)(_?)$// ) { # это транскрипция!
				# / в начале обозначает добавочную транскрипцию
				my $word = $1;
				my $pale = $2;

				# Создаём объект-транскрипцию
				$last_transcr = new_dom_object('transcr');
				$last_transcr->{'word'} = $word;
				$last_transcr->{'pale'} = ($pale eq '_');

				# Сдвиг при вставках: смещается из-за двух звёздочек **.
				$ins_shift = -$last_transcr->{'pale'};
				$ins_pos_prev = 0;

				# Добавляем
				ref_push $kun->{'transcriptions'}, $last_transcr;
			}
			elsif ( $chunk =~ s/^=([\w \-:]+)// ) { # =word
				# 31: *aruiha*=*aruiwa*
				# Уточнение транскрипции.
				my $cl = $1;

				if ( $romaji_or_kiriji ) {
					my $old_word = $last_transcr->{'word'}; # для проверки
					$last_transcr->{'word'} = $cl;
					# Проверяем, что в новое слово отличается только ha/wa
					$cl =~ s/wa/ha/g;
					$cl eq $old_word
						or fail "Bad fixword: '$old_word'"." => '".$last_transcr->{'word'}."'";
				}
			}
			elsif ( $chunk =~ s/^&([\w \-:]+)// ) { # &word
				# Игнорируем слово (не показывается, но учитывается при поиске)
			}
			elsif ( $chunk =~ s/^!(!|R ?)$// ) { # !!, !R
				# Восклицательный знак ! означает, что транскрипция помещается ПОД словом.
				# При этом кол-во транскрипций может быть больше одной (см. 1196).

				# !R - то же, что и !!, но только для русского словаря

				!$kun->{'under'}
					or fail 'parse_kun_chain_chunk: Transcript_under twice';
				$kun->{'under'} = 1;
			}
			elsif ( $chunk =~ s/^!Q(\d)$// ) { # !Qn
				# Восклицательный знак в начале был добавлен в parse_kun_main().
				# Qn - "и" вместо "й" в русской транскрипции ( в n-й позиции).
				my $ipos = $1;

				if ( $cur_trans_type eq 'kiriji' ) {
					my $i_counter=0;
					my $j = 0;
					INNER: # ищем $ipos-тую букву i. Среди всех транскрипций.
					foreach ( @{$kun->{'transcriptions'}} ) {
						my $len = length $_->{'word'};
						for ( $j=0; $j < $len; $j++ ) {
							if ( substr($_->{'word'}, $j, 1) =~ /^[iI]$/
								&& ++$i_counter eq $ipos )
							{
								$j < $len or fail "Wrong i-fix: Q$ipos ($j) in '".$_->{'word'}."'";
								substr($_->{'word'}, $j, 1) .= ':';
								last INNER;
							}
						}
					}
				}
			}
			elsif ( $chunk =~ s/^!(V[TI2]|L1)// ) {
				# ??? Пока игнорируем.
			}
			elsif ( $chunk =~ s/^#([^ ]+) ?$// ) { #NA
				# Постфикс (например ~na)
				my $postfix = $1;
				!defined $kun->{'postfix'} or fail "Two postfixes";
				$kun->{'postfix'} = $postfix;
			}
			elsif ( $chunk =~ s/^([-])(\d+)// ) {
				# Вставки в транскрипцию. Пока только '-'. В n-ную позицию.
				# Непонятно, что такое '!'.
				my $ins_symb = $1;
				my $ins_pos = $2;
				my $mark = $3;

				$ins_pos += $ins_shift;

				# Контролируем, что позиция вставки только увеличивается
				$ins_pos_prev <= $ins_pos or fail;

				substr ( $last_transcr->{'word'}, $ins_pos, 0 ) = $ins_symb; # вставка
				$ins_pos_prev = $ins_pos;
				$ins_shift += length ($ins_symb);
			}
			elsif ( $chunk =~ m/^\^/ ) {
				# Ссылки ^....
				# Разбираются в отдельной процедуре.

				# #52 惟, #211 卸, #343 掛, #856 巧, #1095 旨, #1432 振, #1511 是, #2185 之
				($chunk, my $rem_obj) = parse_remark($chunk);

				my $arr1 = $rem_obj->{'children'};
				if ( $rem_prev && $arr1 && $arr1->[-1]{'type'} ne 'text' ) {
					my $arr2 = $rem_prev->{'children'};
					if ( $arr2 && $arr2->[-1]{'type'} eq 'text' ) {
						add_child $rem_obj, $arr2->[-1]; # Kana tail
					}
				}

				if ( $rem_obj->{'code'} eq '^@' ) { #  Чаще катаканой
					$kun->{'force_katakana'} = 1;
				}
				elsif ( $rem_obj->{'code'} eq '^^' ) { #  Чаще хираганой
					$kun->{'force_hiragana'} = 1;
				}

				ref_push $kun->{'remarks'}, $rem_obj;
				$rem_prev = $rem_obj;
			}
			elsif ( $chunk =~ s/^~(\d+)(!?)//) { # hiragana prefix ~n[!]
				# Длина хираганного префикса (кол-во букв транскрипции, после
				#  которых идёт замена каны иероглифом).
				my $pref = $1;
				my $mark = $2; # Непонятно, что такое '!'

				$kun->{'hiragana_pref'} = $pref;
			}
			elsif ( $chunk =~ s/^([\[\]\+])(\d+)// ) {
				# Вставки символов '[', ']', 'iteration_mark' в слово (на n-ную позицию).
				my $ins_sign = $1;
				my $ins_pos = $2;
				$ins_pos += $word_ins_shift;

				$ins_sign =~ s/\+/$iteration_mark/g;

				$ins_pos = length $kun->{'main'} if $ins_pos > length $kun->{'main'};
				# Check #2160 日, #2411 怖
				$word_ins_pos_prev <= $ins_pos or fail;
				substr ( $kun->{'main'}, $ins_pos, 0 ) = $ins_sign; # вставка
				$word_ins_pos_prev = $ins_pos;
				$word_ins_shift += length $ins_sign;
				#! Если $kun->{'main'} меняется, то с ремарками (ссылками) тоже всё ок.
			}
			elsif ( $chunk =~ s/^(\$\d[^\^~\-#!=&]*)// ) { # $1nnnn
				# Особое форматирование слова.
				my $formatter = $1;

				$kun->{'formatter'} = parse_formatter($formatter);
			}
			$chunk ne $chunk_prev or fail "'$chunk' <> '$chunk_orig'";
		} # end of while ( $chunk !~ /^\s*$/ )
	} # end of  foreach ( @$kun_chain )

	# Убираем бледность у первой транскрипции, если строка и так бледная
	$kun->{'transcriptions'}->[0]->{'pale'} = 0 if $kun->{'pale'};

	return $kun;
} # end of  parse_kun_chain()

# Разбор форматтера
sub parse_formatter {
	my ($chunk) = @_;

	my $chunk_orig = $chunk;

	# Общий синтаксис форматтера: $ N nnnn
	# Где N - слот(позиция), куда вставлять
	# nnnn - номер иероглифа или "hiragana"

	my $res;

	my $pos = 0;
	my $pos_prev = 0;
	while ( $chunk !~ /^\s*$/ ) {
		my $chunk_prev = $chunk;

		if ( $chunk =~ s/^\$(\d)// ) { # $\d - после какой буквы вставлять. $0 - перед словом.
			$pos = $1;
			$pos >= $pos_prev or fail;
			$pos_prev = $pos;
		}
		elsif ( $chunk =~ s/^(\d{4})// ) { # 1234 - ID иероглифа
			ref_push $res->{$pos}, make_kanji($1);
		}
		elsif ( $chunk =~ s/^"([^"]*)"// ) { # "hiragana"
			my $txt = $1;

			$txt =~ s/qi/$iteration_mark/g;
			$txt =~ s/ye/t_/g;

			$txt !~ /[A-Z]/ or fail;

			ref_push $res->{$pos}, kana($txt, 'hiragana');
		}
		elsif ( $chunk =~ s/^([\[\]\+]+)// ) { # просто текст
			my $txt = $1;
			$txt =~ s/\+/$iteration_mark/g;

			ref_push $res->{$pos}, $txt;
		}

		$chunk_prev ne $chunk or fail "parse_formatter: Infinite loop";
	}

	return $res;
}

# Разбор ссылок
sub parse_remark {
	my ($line, $rem_start) = @_;
	$rem_start = '\^' if ! defined $rem_start;

	my $line_orig = $line; # Начальная строка для демонстрации при ошибке.

	my $res = new_dom_object('remark');

	$res->{'text'} = ""; # Дополнительно к {'children'}

	# Сложные случаи: ^_2^^, ^_2^#, но ^_2@, ^!^

	if ( $line =~ s/^$rem_start(_\d|::\d\d|:|!|\+|\-)// ) { # Перед кодом может идти привязка
		$res->{'binding'} = make_binding_obj($1);

		if ( $line =~ s/^(\^\^|\^#)// ) { # Отдельный случай ^_2^^
			$res->{'code'} = $1;
		}
		elsif ( $line =~ s/^(\d|[imorsStvzZ]|\^|\@|\#)// ) { # Остальные коды
			$res->{'code'} = '^'.$1;
		}
	}
	elsif ( $line =~ s/^$rem_start([imorsStvzZ\d]|\^\d|\^|\@|\#)// ) { # Коды без привязки
		$res->{'code'} = '^'.$1;
	}

	defined $res->{'code'} or fail;

	my $line_prev; # Для отлова зависаний (строка должна уменьшаться на каждой итерации).
	while ( $line =~ /^[^\s;]/ ) { # Может идти несколько ссылок подряд.
		$line_prev = $line;

		if ( $line =~ s/^\-// ) { # связка
			# Do nothing
		}
		elsif ( $line =~ s/^(\d{3,4})(?!\d)// ) { # ссылка на кандзи
			my $kanji_num = $1;

			#errmsg("Warning: Short kanji num: '$kanji_num'") if length($kanji_num) < 4;
			add_child  $res, new_dom_object( 'kanji', 'id' => $kanji_num );
			$res->{'text'} .= make_kanji( $kanji_num ); # Дополнительно
			# Не линеаризовывать!
		}
		if ( $line =~ s/^(\d{5})(?!\d)(_?)// ) { # Ссылка на танго
			# (?!\d) - zero-width look-ahead pattern
			my $tan_num = $1;
			my $add_reading = $2;

			my $txt = make_tango( $tan_num, $add_reading );
			add_child  $res, make_text_obj('text', $txt);
			$res->{'text'} .= $txt;
		}
		elsif ( $line =~ s/^"(\^?)([\w \-]+)"// ) {
			my $type = $1; # "^no"; Крышечка ^ означает КАТАКАНУ вместо хираганы.
			my $txt = $2;

			$type ? ( $type = 'katakana' ) : ( $type = 'hiragana' );

			# ^0-1385-"san-o"; --> См. o-KAMI-san
			# После чёрточки - идёт хираганный префикс =/

			if ( $txt =~ s/\-([\w ]+)$// ) {
				my $pref = $1;

				$type eq 'hiragana' or fail;
				$pref = kana($pref, $type);

				unshift @{$res->{'children'}}, make_text_obj('text', $pref);
				$res->{'text'} = $pref.$res->{'text'};
			}

			$txt =~ s/qi/$iteration_mark/g;
			$txt =~ s/ye/t_/g;

			$txt = kana($txt, $type);
			add_child  $res, make_text_obj('text', $txt);
			$res->{'text'} .= $txt;
		}
		elsif ( $line =~ s/^([\/])// ) {
			my $s = $1;
			# / просто серый слеш-разделитель (#45 依);
			add_child  $res, make_text_obj('text', $s);
			$res->{'text'} .= $s;
		}
		elsif ( $line =~ /^$rem_start/ ) {
			# Check #1085 屍
			last;
		}
		elsif ( $line =~ /^\^/ ) {
			$line =~ s/^\^//;
			# Check #2713 厄
		}
		elsif ( $line =~ /^[ \(#]/ ) { # начинается новый элемент
			# Check #1110 詞
			last;
		}
	} continue {
		# Проверка зависаний (строка должна уменьшаться на каждой итерации).
		$line_prev ne $line
			or fail "Infinite loop: '$line' <> '$line_orig'";
	}

	defined $res->{'code'} or fail;

	return ($line, $res);
}

sub make_binding_obj {
	my ($txt) = @_;

	my $obj = {};

	if ( $txt =~ /^_(\d)$/ ) {
		$obj->{'line'} = $1;
	}
	elsif ( $txt =~ /^:$/ ) {
		$obj->{'all'} = 1;
	}
	elsif ( $txt =~ /^::(\d)(\d)$/ ) {
		$obj->{'range'} = [$1, $2];
	}
	elsif ( $txt =~ /^!$/ ) {
		$obj->{'subleft'} = 1;
	}
	elsif ( $txt =~ /^\+$/ ) {
		$obj->{'linefeed'} = 1;
	}
	elsif ( $txt =~ /^\-$/ ) {
		$obj->{'topright'} = 1;
	}

	%$obj or fail;

	return $obj;
}

sub parse_names_kuns {
	my @chunks = @_;

	return if !@chunks;

	!defined $chunks[3] or fail; # [3] - не должно быть

	my @res; # Массив результатов

	for my $i ( 0, 1, 2 ) { # [0] - основные куны, [1] - "также", [2] - "редко";
		my $chunk = $chunks[$i] or next;

		$chunk =~ s/^\$//; # Убираем $ в начале
		$chunk =~ s/\$$//; # Убираем $ в конце

		my @chunk_spl = split /\$/, $chunk; # разделяем по доллару $

		while ( @chunk_spl ) {
			my $s = shift @chunk_spl;

			if ( $s =~ s/^-$// ) { # Следующее слово не показывается
				# Check #129 叡: $ei$-$akira$-$satoshi$ = "Эй"
				shift @chunk_spl;
				next;
			}
			elsif ( $s =~ /^([\w :\-]+)$/ ) { # Слово
				ref_push $res[$i], $s if ( $s !~ /^\s*$/ );
			}
			else {
				fail "Names kuns: '$s' / '$chunk'";
			}
		}
	}

	return \@res;
}
#----------------------------------------------------------------------

sub format_rusnick {
	my ($rusnick) = @_;

	if ( !$rusnick ) {
		return atext_colored( 'notedited',  "Данные не отредактированы");
	}

	$rusnick =~ s/^\*//; # убираем лишнюю звёздочку в начале #2828 率
	$rusnick =~ s/\*$//; # и в конце

	$rusnick !~ /^\*/ or fail;
	$rusnick !~ /\*$/ or fail;

	my @rusnick_spl = split /\*/, $rusnick; # разделитель - звёздочка *

	my @tmp = (); # Нужно промежуточное представление

	foreach my $s ( @rusnick_spl ) {
		next if $s eq '_'; # означает, что ники пишутся на одной строке?
		$s =~ /^[\w\- \.!"\(\)]+/ or fail;

		if ( $s =~ /^!(\d+)$/ ) { # #1391 城: замок*!2
		# ударение
			@tmp == 1 or fail;

			substr( $tmp[0], $1, 0 ) = $stress_mark; # вставляем символ ударения
			next;
		}

		# Параноя
		$s !~ /[\.!\)]./ or fail;
		$s =~ /[а-я]/ or fail;

		push @tmp, $s;
	}

	my $res = '';

	foreach my $s ( @tmp ) {
		$s = format_text( $s );
		$s = '['.atext_ucfirst($s).']';
		$res .= " ".atext_colored( 'rusnick', $s );
	}

	return $res;
}

sub format_onyomi {
	my ($onyomi) = @_;

	# Тёмный шрифт обозначается двумя звёздочками. Мне это не нравится -
	# я хочу разделять по звёздочке. Поэтому я переобозначаю "тёмные" слова
	# с помощью подчёркивания.
	$onyomi =~ s/\*\*/_*/g;

	$onyomi =~ s/^\*//; # Убираем звёздочки в начале
	$onyomi =~ s/\*$//; # и в конце

	$onyomi !~ /^\*/ or fail;
	$onyomi !~ /\*$/ or fail;


	my @onyomi_spl = split /\*/, $onyomi;

	my $res = '';
	my $kokuji = 0;

	foreach my $s ( @onyomi_spl ) {
		$s or fail;

		if ( $s =~ /^-/ ) {
			$kokuji = 1;
		}
		elsif ( $s =~ /^([a-z:\-,;\(\)]+_?)/ ) { # остальной текст
			my $text = $1;
			my $pale = ( $text =~ s/_$// ); # бледный, если заканчивается на подчёркивание

			# Добавляем пробелы
			$text =~ s/([;,])/$1 /g;
			$text =~ s/([\(])/ $1/g;

			$text = cur_trans( $text );
			$text !~ /[\^#]/ or fail;

			$text = uc $text if  $romaji_or_kiriji; # Uppercase

			$text = atext_pale($text) if $pale;

			$res .= $text;
		}
		else {
			fail "Something strange in onyomi: '$s' in '$onyomi'";
		}
	}

	$res = atext_colored( 'onyomi', $res);

	if ( $kokuji ) {
		$res .= " ".atext_colored('kokuji', '<Кокудзи>');
	}

	return $res;
}

# Ссылки в шапке статьи
sub format_remarks_glob {
	my ($remarks) = @_;

	return if ! defined $remarks;

	# Группируем ссылки по коду
	my $grouped_remarks;
	foreach ( @$remarks ) {
		my $code = $_->{'code'};
		ref_push $grouped_remarks->{$code}, $_;
	}

	my $res = '';

	foreach ( keys %$grouped_remarks ) {
		my $code = $_;
		my $rem = format_remarks( $grouped_remarks->{$code} );

		my $color = undef;
		if ( $code =~ /^([\^\$\*])/ ) {
			$color = 'pref'.$1;
			$color =~ tr/\^\$\*/112/;
		} else {
			fail "Unkown remark code: '$code'";
		}

		$res .= '  ' if $res;
		$res .= atext_colored( $color, $rem );
	}

	return $res;
}

# Таблица различных кунов
sub format_kun_table {
	my ($kuns, $kuns_rus) = @_;

	my $kun_table = new_dom_object('vtable', 'kuns');
	#$kun_table->{'spacing'} = 0;

	my $i = 0;
	foreach ( @$kuns ) {
		my $rus = $kuns_rus->[$i++];

		my $row_obj = format_kun_table_row($_, $rus);

		add_child  $kun_table, $row_obj;
	}
	return $kun_table;
}

# Кана из предыдущей ссылки используется в следующей (#211 卸, #1432 振)
sub get_remark_kana_tail {
	my ($remark) = @_;

	my $arr = $remark->{'children'};

	my $i;
	for ( $i = $#$arr; $i >= 0; $i-- ) {
		my $elem = $arr->[$i];
		if ( $elem->{'type'} ne 'text' ) {
			last;
		}
	}
	$i++;
	if ( $i < @$arr ) {
		return  [ @$arr[$i .. $#$arr] ]; # Диапазон от $i до конца массива
	}
}

# Кун с переводом
sub format_kun_table_row {
	my ($kun, $rus) = @_;

	# Создаём таблицу, с транскрипцией, номерами пунктов, ссылками и т. д.

	# level one:  htable:  kun | russian
	my $row = new_dom_object( 'htable', 'kun table' );
	$row->{'spacing'} = 2;

	$row->{'left'} = format_kun_column($kun); # kun:  word, transcriptions
	$row->{'right'} = format_russian_column( $rus, $kun, $row ); # russian:  номера пунктов, ссылки
	$row->{'pale'} = $kun->{'pale'};

	if ( defined $rus->{'pre'} ) {
	# Вставка между словом и значением (#95 院, parse_kun_rus)
		my $tmp = $rus->{'pre'};

		# добавляем к первой строке левой колонки
		$row->{'left'} =~ s/(\n|$)/ $tmp$1/;
	}

	return $row;
}

# word, transcriptions
sub format_kun_column {
	my ($kun, $row) = @_;

	my $res = '';

	my $word = format_word( $kun, $objects->{'main_kanji'}, ($kun->{'hiragana_pref'} or 0) );

	# Inserts
	if ( defined $kun->{'formatter'} ) {
		foreach my $pos ( keys %{$kun->{'formatter'}} ) {
			splice ( @$word, $pos, 0, @{$kun->{'formatter'}{$pos}} );
		}
	}

	$word = join '', @$word;
	$res .= $word;

	if ( $kun->{'under'} ) { # транскрипция снизу #2664
		$res .= "\n";
	}

	# DBG:
	#$word =~ s/\^K\d{4}(.)#/$1/g;
	#print STDERR encode_utf8 (
			#$objects->{'article_num'}.":".$word."|"
			#.join(",", map {$_->{'word'}} @{$kun->{'transcriptions'}})."\n" );

	# транскрипции
	foreach my $tr_obj ( @{$kun->{'transcriptions'}} ) {
		$res .= " " if $res !~ /\s$/;
		$res .= make_transcr( $tr_obj, $kun );
	}

	if ( defined $kun->{'postfix'} ) { # "#NA"
		my $postfix = $kun->{'postfix'};
		$postfix = ' ~'.cur_trans(lc $postfix); #   "NA" -> "~na"
		$postfix = atext_colored( 'particle', $postfix );

		# добавляем к первой строчке куна
		$res =~ s/(\n|$)/ $postfix$1/;
	}

	return $res;
}

sub make_transcr {
	my ($obj, $kun) = @_;

	my $word = $obj->{'word'};
	my $pale = ( defined $obj->{'pale'} && $obj->{'pale'} );

	my $color = 'red';
	if ( $word =~ /^[A-Z]/ ) { # Пробелы из начала УЖЕ должны быть убраны
		$color = 'cyan';
		$word = lc $word;
	}

	# Transcription text
	my $res = '';
	my $arr;
	while ( $word ne '' ) {
		my $word_prev = $word;
		if ( $word =~ s/^([a-z: \-]+|[A-Z: \-]+)// ) {
			# обрабатываем abc и ABC отдельно, т.к. иногда (????) встречаются
			# транскрипции, где два слова не отделены пробелом,
			# и чтобы отделить их, они написаны в разном регистре.
			$res .= cur_trans(lc $1);
		}
		elsif ( $word =~ s/^([^a-zA-Z: \-]+)// ) { # остальные символы
			$res .= $1;
		}
		$word ne $word_prev or fail "Infinite loop: '$word'";
	}

	$res = "[".$res."]";

	$res = atext_colored('transcr_'.$color, $res);
	$res = atext_pale($res) if $pale;

	return $res;
}

# Значение куна: несколько пунктов, ссылки и т. д.
sub format_russian_column {
	my ($rus, $kun, $row) = @_;

	my @meanings;
	my @is_meaning_pale;

	# Собираем пункты списка значений
	if ( defined $rus->{'zero'} ) {
		$meanings[0] = $rus->{'zero'}{'text'};
		$is_meaning_pale[0] = 0;
	}

	my $i = 0;
	foreach (  @{ $rus->{'meanings'} }  ) {
		$i++;
		$meanings[$i] = $_->{'text'};
		$is_meaning_pale[$i] = defined $_->{'pale'} && $_->{'pale'};
	}

	# Ссылки
	my $remarks = $kun->{'remarks'};

	my $bindings = undef; # привязки
	if ( defined $remarks ) {
		my $prev = undef;
		foreach ( @$remarks ) {
			my $binding = '';

			# Распространяем привязку на все ссылки с тем же кодом
			if ( !defined $_->{'binding'}
				&& defined $prev
				&& $_->{'code'} eq $prev->{'code'}
				&& defined $prev->{'binding'}
			) {
				$_->{'binding'} = $prev->{'binding'};
			}

			# определяем, к какому пункту привязывать ссылку.
			if ( defined $_->{'binding'} ) {
				my $b_obj = $_->{'binding'};

				if ( defined $b_obj->{'line'} ) {
					my $elem_num = $b_obj->{'line'};
					ref_push $bindings->{$elem_num}, $_;
				}
				elsif ( defined $b_obj->{'range'} ) {
					my $from = $b_obj->{'range'}->[0];
					#my $to = $b_obj->{'range'}->[1];

					ref_push $bindings->{$from}, $_;
				}
				elsif ( defined $b_obj->{'all'} ) {
					ref_push $bindings->{1}, $_;
				}
				elsif ( defined $b_obj->{'subleft'} ) {
					ref_push $bindings->{'u'}, $_; # под таблицей
				}
				elsif ( defined $b_obj->{'linefeed'} ) {
					my $last_line_num = @meanings - 1;
					ref_push $bindings->{$last_line_num}, $_;
				}
				elsif ( defined $b_obj->{'topright'} ) {
					ref_push $bindings->{0}, $_;
				}
				else {
					fail "Unknown binding";
				}
			}
			else {
				# Добавляется к последней строке (#254 霞)
				my $last_line_num = @meanings - 1;
				ref_push $bindings->{$last_line_num}, $_;
			}
		} continue {
			$prev = $_;
		}
	}

	if ( defined $bindings->{'u'} ) {
		# добавляем в конец левой колонки
		my $rem = format_remarks( $bindings->{'u'}, $kun );
		$row->{'left'} .= "\n". atext_colored('remark', $rem);
	}

	my $result_vtable = new_dom_object( 'vtable', 'kun meaning (right half)' );
	$result_vtable->{'pale'} = 1 if $rus->{'pale'};

	for ( $i = 0; $i < @meanings; $i++ ) {
		my $meaning = $meanings[$i];

		next if !defined $meaning; # zero line is usually not defined.

		my $rem_table = new_dom_object('htable', 'несколько пунктов, объединённых ссылкой');

		my $span_to = $i; # по умолчанию ссылка добавляется к одной строке

		if ( defined $bindings->{$i} ) {
			my $b_refs = $bindings->{$i};

			my $b_obj = $b_refs->[0]->{'binding'}; # У всех ссылок в группе @$b_refs одинаковые привязки

			$remarks = format_remarks( $b_refs, $kun );
			$remarks = atext_colored('remark', $remarks);

			if ( !defined $b_obj || defined $b_obj->{'line'} ) {
				$meaning .= "  ".$remarks;
			}
			elsif ( defined $b_obj->{'range'} || defined $b_obj->{'all'} ) {
				my $from = 1;
				if ( defined $b_obj->{'range'} ) {
					($from, $span_to) = @{$b_obj->{'range'}};
				}
				elsif ( defined $b_obj->{'all'} ) {
					$from = 1;
					$span_to = @meanings - 1;
				}
				$from == $i or fail "По построению";

				my $join = new_dom_object('htable', "Join");
				# таблица, состоящая из вертикальной черты (слева) и ссылки (справа)
				my $join_line = "|\n" x ($span_to-$from+1);
				$join_line =~ s/\n$//;

				$join->{'left'} = atext_colored('remark', $join_line);

				my $vert_space = "\n" x ( ($span_to - $from) / 2 );
				$join->{'right'} = $vert_space.$remarks;
				$join->{'spacing'} = 1;

				# добавляем в правую колонку $rem_table
				$rem_table->{'right'} = $join;
				$rem_table->{'spacing'} = 1;
			}
			elsif ( defined $b_obj->{'topright'} ) {
				$meaning =~ s/(\n|$)/  $remarks$1/;
			}
			else {
				fail;
			}
		}

		# Левая часть - объединённые одной ссылкой пункты
		my $meanings_gr_table = new_dom_object('vtable', 'meanings grouped left');
		$rem_table->{'left'} = $meanings_gr_table;

		# Для номеров пунктов делается отдельная таблица, чтобы сделать
		# красивое выравнивание (слева), когда в пункте несколько строк.
		while (1) {
			if ( $i > 0 ) {
				my $meaning_table_for_item_num =
						new_dom_object('htable', 'таблица для выравнивания пунктов');
				$meaning_table_for_item_num->{'left'} = $i.'. '; # номер пункта "1. "
				$meaning_table_for_item_num->{'right'} = $meaning;
				$meaning_table_for_item_num->{'pale'} = 1 if $is_meaning_pale[$i];

				$meaning = $meaning_table_for_item_num;

			} else {
				$meaning = atext_pale($meaning) if $is_meaning_pale[$i];
			}

			add_child $meanings_gr_table, $meaning;

			last if ( !defined $span_to || $i >= $span_to );
			#else

			$meaning = $meanings[++$i];
		};

		add_child $result_vtable, $rem_table;
	}

	return $result_vtable;
}

sub format_remarks {
	my ($b_remarks, $kun) = @_;

	my $remarks = '';

	my $M = @$b_remarks; # кол-во объектов
	my $prev; my $saved_code;
	for (my $j = 0; $j < $M; $j++ ) {
		my $r = $b_remarks->[$j];
		defined $r or fail;
		defined $r->{'code'} or fail;

		$saved_code = $r->{'code'}; # чтобы потом обратно вернуть
		if ( defined $prev && $r->{'code'} eq $prev->{'code'} ) {
			$r->{'code'} = ''; # присоединяем к предыдущей ссылке, если код тот же
		}

		if ( defined $prev && $r->{'code'} ne $prev->{'code'} ) {

			if ( defined $r->{'binding'}{'linefeed'} ) {
				# Так-то здесь должен быть перенос строки, как в #387 勧
				# Do nothing
			}

			$remarks .= ", ";
		}

		my $remark = '';
		if ( defined $kun ) {
			$remark = format_remark( $r, $kun);
		} else {
			$remark = format_remark( $r );
		}

		if ( $j > 0 && !defined $r->{'binding'}{'linefeed'} ) {
			# Текст начинается с маленькой буквы
			$remark = atext_lcfirst($remark);
		}

		$remarks .= $remark;

		$prev = $r;
		$prev->{'code'} = $saved_code;
	}

	return $remarks;
}

sub format_remark {
	my ($remark, $kun) = @_;
	defined $remark or fail;

	my $res = '';

	my $code = $remark->{'code'};

	if ( $code ne '' ) {
		defined $code_names{$code} or fail "format_remark: undef code_names: '$code'";
		$res .= $code_names{$code}.' ';
	}

	if ( defined $remark->{'children'} ) {
		my $remchildren = $remark->{'children'};

		for ( my $i=0; $i < @$remchildren; $i++ ) {
			my $obj = $remchildren->[$i];

			my $notail = 0;
			$notail = 1 if !defined $kun;
			$notail = 1 if !defined $kun->{'main'};
			$notail = 1 if defined $remchildren->[$i+1]; # не последний элемент
			$notail = 1
				if ($i>0 && $remchildren->[$i-1]->{'type'} eq 'kanji'); # предыдущим был кандзи #683 傾

			if ( $obj->{'type'} eq 'kanji' && !$notail ) {
				my $word = format_word ($kun, $obj->{'id'}, 0);
				$res .= join '', @$word;
			}
			else {
				my $type = $obj->{'type'};
				if ( $type eq 'kanji' ) {
					$res .= make_kanji( $obj->{'id'} );
				}
				elsif ( $type eq 'text' ) {
					if ( $obj->{'text'} eq '/' ) {
						$res .= atext_colored( 'rem_text', $obj->{'text'} );
					} else {
						$res .= $obj->{'text'};
					}
				}
				else {
					fail "Unknown type: '$type'";
				}
			}
		}
	}

	return $res; # Not colored
}

sub format_text {
	my ($txt) = @_;

	# Замена кавычек на русские <<ёлочки>>
	$txt =~ s/"([^"]*)"/$laquo.$1.$raquo/eg;

	# Добавляем пробелы после знаков препинания, если это не многоточие
	# и не конец строки
	$txt =~ s/([\.,;\?!])(?!([ \^\)\]\.,;\?!»]|$))/$1 /g;

	if ( $txt =~ s/"/$laquo/eg ) {
		errmsg ("Unpaired quote mark");
	}

	return $txt;
}

sub format_word { # Не линеаризовывать!
	my ($kun, $kanji_id, $kanji_from) = @_;

	my $word = lc $kun->{'main'};

	my $kanji_size = $kun->{'kanjisize'} || length $kun->{'main'};
	$kanji_size eq int($kanji_size) or fail "wrong kanji_size: '$kanji_size'";

	my @res = (); # Массив нужен, чтобы потом делать вставки.

	# до иероглифа
	if ( $kanji_from > 0 ) {
		my $pre_kanji = substr($word, 0, $kanji_from);
		$pre_kanji =~ s/ //g; # В кане пробелы опускаются
		push @res, split //, kana( $pre_kanji, 'hiragana' );
	}

	substr($word, $kanji_from, $kanji_size ) =~ /^[\w:' \-]+$/
		or fail "Strange symbols under kanji: '$word', $kanji_from, $kanji_size";

	push @res, make_kanji($kanji_id);

	# остаток слова
	if ( $kanji_size < length $word ) { # Не $kanji_from+$kanji_size, а именно $kanji_size #640 苦
		my $post_kanji = substr( $word, $kanji_size );
		$post_kanji =~ s/ //g; # В кане пробелы опускаются
		push @res, split //, kana( $post_kanji, 'hiragana' );
	}

	return \@res;
}

sub format_footer {
	my ($footer) = @_;

	return unless defined $footer;

	my $res;

	if ( $footer eq '~' ) {
		$res = "Отсутствует в словаре Н. И. Фельдман-Конрад.";
	}
	elsif ( $footer eq '~~' ) {
		$res = "В словаре Н. И. Фельдман-Конрад представлен устаревшей формой.";
	}
	elsif ( $footer eq '~~~' ) {
		$res = "В словаре Н. И. Фельдман-Конрад представлен оригинальной формой.";
	}
	elsif ( $footer eq '~~~~' ) {
		$res = "В словаре Н. И. Фельдман-Конрад представлен упрощённой формой.";
	}
	else {
		fail "format_footer: unknown code: $footer";
	}

	return $res;
}

sub format_tango {
	my ($comp_defs) = @_;

	my $res = new_dom_object('vtable', "Tango Groups");
	$res->{'spacing'} = 1;

	my @titles = ();
	@titles = @{$objects->{'tango_titles'}} if defined $objects->{'tango_titles'};

	my $i = 0;
	foreach my $title ( @titles ) {
		$i++;

		my $row_num = $i;
		$row_num = 0 if @titles < 2; # не показывать номера, если всего один пункт

		if ( $objects->{'tango_header_replace'} ) {
			$row_num == 0 or fail;
			$title = ''; # Заголовок значения перенесён в общий заголовок
		}

		my $main_row_table = new_dom_object('vtable', "Row Table");
		{
			if ( $title ) {
				$title = parse_tango_title( $title );

				my $title_table = new_dom_object('htable', "Tango title table");
				if ( $row_num ) {
				# Номер пункта
					$title_table->{'left'} = atext_colored('tan_title', $row_num.')');
				}
				else {
				# Если без номера пункта, то с заглавной буквы
					$title = atext_ucfirst( $title );
				}

				$title_table->{'right'} = atext_colored('tan_title', $title);
				$title_table->{'spacing'} = 1;

				add_child $main_row_table, $title_table;
			}

			if ( defined $comp_defs->{$i} ) {
				my $last = !defined $comp_defs->{$i+1};
				add_child $main_row_table, format_tango_block( $comp_defs->{$i}, $last );
			} else {
				# Do nothing. Пустой блок
			}
		}

		add_child( $res, $main_row_table ); # add to vtable
	}

	return $res;
}

my $marker_r_chr = chr(9671); # Ромб
my $marker_g_chr = chr(9651); # Треугольник
my $names_1_chr = '1'; # единица в квадратике [1] #8321, #9843

sub format_tango_block {
	my ($block, $last) = @_;

	is_array($block) or fail "Array wanted.";

	my $block_body = new_dom_object('vtable', "Tango block");

	# Отделение нестандартных значений в конце пустой строкой
	my $nonstand_separator = @$block+1; # недостижимый индекс
	if ( $last ) {
		for (my $j = $#$block; $j>=0; $j--) {
			my $row = $block->[$j];
			if ( !$row->{'marker'}
				 || $row->{'marker'} ne '*' && $row->{'marker'} ne '&' )
			{
				$nonstand_separator = $j + 2;
				last;
			}
		}
	}

	my $i=0;
	foreach ( @$block ) {
		$i++;
		# Отделение нестандартных значений в конце пустой строкой
		if ( $i == $nonstand_separator ) {
			add_child $block_body, "";
		}

		my $tango_id = $_->{'tango_id'}; # Tango id in database

		if ( defined $_->{'msgid'} ) {
			my $msg = "\n".tango_message($_->{'msgid'});

			add_child $block_body, atext_colored('message', $msg);
		}

		next if !defined $tango_id;

		if ( ! defined $objects->{'tan_objs'}{$tango_id} ) {
			my $row = fetch_tango_full( $tango_id );
			$row or fail "No such record in the database: Tango $tango_id";
			$objects->{'tan_objs'}{$tango_id} = parse_tan( $row );
		}
		my $tango_obj = $objects->{'tan_objs'}{$tango_id};

		my $line_table = new_dom_object( 'htable', "Tango line" );
		$line_table->{'spacing'} = 2;

		$line_table->{'left'} = format_tango_word_and_transcr( $tango_obj, $_->{'marker'} );

		$line_table->{'right'} = format_russian_column( $tango_obj->{'russian'} );

		add_child($block_body, $line_table);
	}
	return $block_body;
}

sub format_tango_alone {
	my ($num) = @_;

	my $tango_obj = fetch_tango_full($num);
	return undef if !$tango_obj;

	$cur_block = 'Tango';

	$tango_obj = parse_tan($tango_obj);

	my $line_table = new_dom_object( 'htable', "Tango line" );

	$line_table->{'spacing'} = 2;
	$line_table->{'left'} = format_tango_word_and_transcr( $tango_obj );
	$line_table->{'right'} = format_russian_column( $tango_obj->{'russian'} );

	return $line_table;
}

sub tango_message {
	my ($num) = @_;

	# используемые кандзи нужно регистрировать в парсере parse_compounds().

	if ($num == 1 ) { #1330 - 小
		return "(Чтение «о-» типично для фамилий и топонимов.)";
	}
	if ($num == 2 ) { #2482 - 米
		return "Значение «88-летие» построено"
				."\nна декомпозиционной игре ".make_kanji(2482)." = "
				.make_kanji(2268).", ".make_kanji(1251).", ".make_kanji(2268).".";
	}
	if ($num == 3 ) { #2496 - 編
		return "В нижеследующих значениях заменяет знак ".make_kanji(2495).":";
	}
	if ($num == 4 ) { #2088 - 憧
		return atext_colored('names_header',
				"Знак не используется в именах собственных,"
				."\nно может встречаться в названиях фирм,"
				."\nторжественных меропреятий и т.п." );
	}
	if ($num == 5 ) { #2184 - 廼
		return "Номинально знак считается синонимом и"
				."\nомонимом ".make_kanji(2183).", но в таком использовании"
				."\nпрактически не встречается.";
	}
	if ($num == 6 ) { #2535 - 捧
		return "В сочетаниях может заменяться знаком ".make_kanji(2528).".";
	}
	if ($num == 7 ) { #2336 - 誹
		return "Иногда может заменяться знаком ".make_kanji(2339).".";
	}
	if ($num == 8 ) { #1671 - 痩
		return "В словах с чтением «ясэ» может заменяться на ".make_kanji(4638).".";
	}
	if ($num == 9 ) { #729 - 欠
		return "До упрощения знака ".make_kanji(5033)." («недостача», «кэцу»)"
				."\nзнак ".make_kanji(729)." имел только чтение «кэн»"
					." и значение «зевота». ";
	}
	if ($num == 10 ) { #260 - 画
		return "Вариант ".make_kanji(318)." считается устаревшим, но часто"
				."\nупотребляется в значениях 2 и 3.";
	}
	if ($num == 11 ) { #315 - 柿
		return "Фактически, это два разных знака. Иероглиф"
				."\n«дранка» первоначально выглядел как"
				."\n(символ, отсутствующий в юникоде, сорри)"
				."\nи поэтому должен писаться в восемь черт."
				."\nЕго китайское чтение - «ХАЙ».";
	}
	if ($num == 12 ) { #278 - 恢
		return "Во втором значении заменяется знаками ".make_kanji(271)." и ".make_kanji(275).".";
	}
	if ($num == 13 ) { #1280 - 准
		return "Данный знак изначально являлся вариантом ".make_kanji(1286).","
				."\nно сегодня считается самостоятельным иероглифом,"
				."\nстандартно использующимся во всех приведённых сочетаниях.";
	}
	if ($num == 16 ) { #318 - 劃
		return "Знак считается устаревшим, но"
				."\nпродолжает употребляться наряду с ".make_kanji(260).".";
	}
	if ($num == 17 ) { #1055 - 撒
		return "В сочетаниях с чтением «сан» часто заменяется на ".make_kanji(1056).".";
	}
	if ($num == 18 ) { #1279 - 駿
		return "Во многих сочетаниях заменён знаком ".make_kanji(1273).".";
	}
	if ($num == 19 ) { #206 - 臆
		return "Во втором значении заменён знаком ".make_kanji(205)."."
				."\nЧасто заменяется им и в первом значении.";
	}
	if ($num == 20 ) { #869 - 昂
		return "В сочетаниях заменяется на ".make_kanji(912)." или ".make_kanji(593).".";
	}
	if ($num == 21 ) { #2649 - 民
		return "(Большинство этих слов могут означать"
				."\nкак группу людей, так и члена группы:"
				."\n«гражданин», «крестьянин», «подданный» и т.п.)";
	}
	if ($num == 22 ) { #2752 - 雄
		return "Иногда заменяет знак ".make_kanji(2732)." со значением «мужество».";
	}
	if ($num == 23 ) { #2918 - 呂
		return "Чтение «рё» характерно для китайских имён.";
	}
	if ($num == 24 ) { #1731 - 打
		return "(префикс «бути» чаще записывается хираганой)";
	}
	if ($num == 25 ) { #5108 - 肓
		return "Чтение «мо:» считается ошибочным.";
	}
	if ($num == 26 ) { #4371 - 滲
		return "В сочетаниях с чтением «син» может заменять знак ".make_kanji(1437).".";
	}
	if ($num == 27 ) { #200 - 岡
		return "Иногда заменяется знаком ".make_kanji(2559).".";
	}
	if ($num == 28 ) { #822 - 御
		return "Префикс ".cur_trans("o-")." чаще пишется хираганой.";
	}
	if ($num == 29 ) { #4901 - 籔
		return "С точки зрения употребления в именах знак следует"
				."\nсчитать синонимичным знаку ".make_kanji(5329).". Тем не менее,"
				."\nэто разные иероглифы, вопреки утверждениям"
				."\nнекоторых словарей.";
	}
	if ($num == 30 ) { #6282 - 鷸
		return "Названия видов птиц см. в статье для знака ".make_kanji(1146).".";
	}
	if ($num == 31 ) { #3057 - 傅
		return "Часто встречается ошибочное употребление этого знака в именах вместо ".make_kanji(3062).".";
	}

	fail "Unknown tango_message num: '$num'";
}

sub format_tango_word_and_transcr {
	my ($tango_obj, $marker) = @_;

	my $res = '';

	# DBG:
	#my $word = $tango_obj->{'word'};
	#$word =~ s/\^K\d{4}(.)#/$1/g;
	#print STDERR encode_utf8 ( ""
			##$tango_obj->{'nomer'}.":"
			#.$word."|"
			#.join(",", map {$_->{'text'}} @{$tango_obj->{'readings'}})
			#."\n" );


	if ( defined $marker && $marker ne '' ) {
		if ( $marker eq '*' ) { # ромб
			$res .= atext_colored('marker_r', $marker_r_chr).' ';
		}
		elsif ( $marker eq '^' ) { # треугольник
			$res .= atext_colored('marker_g', $marker_g_chr).' ';
		}
		elsif ( $marker eq '&' ) { # ромб и треугольник
			$res .= atext_colored('marker_r', $marker_r_chr); # ромб
			$res .= atext_colored('marker_g', $marker_g_chr); # треугольник
		}
		elsif ( $marker eq '@' ) { # [1]
			$res .= atext_colored('names_1', $names_1_chr).' ';
			# Если имя состоит из одного иероглифа и рядом помещен значок [1],
			# то это означает, что по соответствующему чтению (обычно не входящему
			# в общий список) данный иероглиф может читаться только в одиночку
			# и никогда в сочетаниях с другими знаками.
		}
		else {
			fail "Unknown marker: '$marker'";
		}
	} else {
		# Marker is not defined
		$res .= '  ';
	}

	$res .= $tango_obj->{'word'};

	return $res if ( $tango_obj->{'no_kanji'} && $cur_trans_kana );

	foreach ( @{$tango_obj->{'readings'}} ) {
		$res .= " ";

		my $transcr = '';

		# Чаще катаканой, как в #1:4)
		if ( defined $tango_obj->{'force_katakana'} && $cur_trans_type eq 'hiragana' ) {
			$transcr = kana( uc $_->{'text'}, 'katakana');
		}
		elsif ( defined $tango_obj->{'force_hiragana'} && $cur_trans_type eq 'katakana' ) {
			$transcr = kana(lc $_->{'text'}, 'hiragana');
		}
		else {
			$transcr = cur_trans($_->{'text'});
		}

		$transcr = "[". $transcr ."]";

		$transcr = atext_colored('transcr_red', $transcr);

		$transcr = atext_pale($transcr) if ( $_->{'pale'} );

		$res .= $transcr;
	}

	return $res;
}

sub format_names_list {
	my ($kuns_arr) = @_;

	return if ( !@$kuns_arr );

	defined $kuns_arr->[0] && @{$kuns_arr->[0]} or fail;
	!defined $kuns_arr->[3] or fail;

	my $res = "";

	$res .= join ", ", map { cur_trans($_) } @{$kuns_arr->[0]};

	if ( defined $kuns_arr->[1] ) {
		$res .= ", ".atext_italic("также ");
		$res .= join ", ", map { cur_trans($_) } @{$kuns_arr->[1]};
	}

	if ( defined $kuns_arr->[2] ) {
		$res .= ", ".atext_italic("редко ");
		$res .= join ", ", map { cur_trans($_) } @{$kuns_arr->[2]};
	}

	if ( $res !~ /,/ ) { # всего одно слово
		$res = $laquo.$res.$raquo; # добавляем кавычки вокруг
	}

	$res = atext_ucfirst($res);
	$res = atext_colored('names_header', $res);

	return $res;
}

sub format_names {
	my ($comp_defs) = @_;

	my $main_row_table = new_dom_object('vtable', "Row Table");

	add_child $main_row_table, format_tango_block( $comp_defs->{'N'} );

	return $main_row_table;
}

sub format_utility {
	my ($code) = @_;

	my $res = "";

	defined $utility{$code} or fail "Unknown utility code: '$code'";

	return atext_colored( 'utility', $utility{$code} );
}

sub format_strokes {
	my ($num) = @_;

	my $st_word;

	my $num_rest = $num % 100;
	$num_rest = $num % 10 if ( $num > 20 );
	if ( $num_rest >= 5 ) {
		$st_word = "черт";
	}
	elsif ( $num_rest >= 2 ) {
		$st_word = "черты";
	}
	elsif ( $num_rest == 1 ) {
		$st_word = "черта";
	}
	else {
		$st_word = "черт";
	}

	return atext_colored ( 'strokes', "(".$num." ".$st_word.")" );;
}

sub parse_kan_russian {
	my ($line) = @_;

	return if $line eq '?';

	$line =~ s/^\|//;     # Убираем | в начале строки. #1588 泉

	# #1592 潜: водолаз/|&проходить,пролезать
	$line =~ s{/\|}{/}g;

	# #1316 - разделено двумя чертами ||
	my @line_split = split(/\|+/, $line);

	my $russian = $line_split[0];

	my $tango_rus_headers = $line_split[1];

	# Проверяем, что нет необработанных элементов
	!defined $line_split[2] or fail "$line_split[2]";

	# Parsing russian
	$russian = parse_rus_prefixes($russian) if $russian; # Не вносить в следующий блок! #2171 禰

	# Часть $russian - это куны, а часть - заголовки блоков составных слов.
	my $kun_i = 0;
	while ( $russian ) {
		if ( defined $objects->{'kuns'}
			&& defined $objects->{'kuns'}->[$kun_i] )
		{
			$kun_i++;
			if ( $russian =~ s{^([^/]+)(/|$)}{} ) {
				ref_push $objects->{'kuns_rus'}, parse_kun_rus( $1 );
			} else {
				fail "$russian";
			}
		}
		else { # остальное - заголовки блоков танго
			!$tango_rus_headers or fail;
			$tango_rus_headers = $russian;
			$russian = "";
		}
	}

	if ( defined $objects->{'messages'} ) {
		$dom->{'message'} = '';
		foreach my $txt ( @{$objects->{'messages'}} ) {
			$txt = atext_ucfirst( $txt );
			$dom->{'message'} .= "\n".atext_colored('message', $txt)."\n";
		}
	}

	return unless $tango_rus_headers;

	$objects->{'tango_titles'} = [split '\/', $tango_rus_headers];

	if ( $tango_rus_headers =~ /^(@.)/
		&& ! defined $objects->{'tango_titles'}->[1] )
	{
		defined $tan_title_abbrevs{$1} or fail "Unknown tan_title_abbrevs '$1'";

		$objects->{'tango_header_replace'} = 1;
	}
}

sub parse_rus_prefixes {
	my ($txt) = @_;

	while ( 1 ) { # неопределённое кол-во итераций
		my $txt_prev = $txt;

		if ( $txt =~ /^[\^\*\$]/ ) { # String starts with [^*$]
			if ( $txt =~ s/^([\^\*\$][0-9\?iort])(\d{4})// ) { # [^*$] [0-9] 3456
				my $pref_code = $1;
				my $kanji_id = $2;

				my $remark_obj = new_dom_object('remark_glob');
				$remark_obj->{'code'} = $pref_code;
				add_child  $remark_obj, new_dom_object('kanji', 'id' => $kanji_id );
				ref_push  $objects->{'remarks_glob'}, $remark_obj;
			}
			else {
				fail "Strange rus pref: $txt;";
			}
		}
		# =
		elsif ( $txt =~ s/^=(.*)$// ) { # Не '~='!!! #5412 蝪
			my $tmp = 'Номинальное значение: «'.$1.'».'."\n";
			#.'Сочетания малочисленны и неупотребительны.';
			ref_push $objects->{'messages'}, $tmp;
			last;
		}
		elsif ( $txt =~ s/^(~+)(?![~\d-])// ) { # (?! шаблон) # check #3720 悖, #3000 价
		# ~~~ в словаре Н. И. Фельдман-Конрад
			my $txt = format_footer($1);
			!defined $dom->{'footer'} or fail $dom->{'footer'};
			$dom->{'footer'} .= $txt;
		}

		last if ($txt eq $txt_prev);
	}

	$txt =~ s{^/}{}; # Иногда в начале остаётся слэш / #4472 爍

	$dom->{'remarks_glob'} = format_remarks_glob( $objects->{'remarks_glob'} );

	return $txt;
}

sub parse_kun_rus {
	my ($kun_rus) = @_;

	my $result = {};

	if ( $kun_rus =~ s/^>([^&]+)&/&/ ) {
	# Extra column between kun and meaning (see 95)
		my $txt = $1;
		$result->{'pre'} = parse_text_russian( $txt );
	}

	my @lines;

	@lines = split '&', $kun_rus;

	my $zero = shift @lines;

	if ( defined $zero && $zero ne '' ) {
		my $meaning = new_dom_object('meaning');

		$meaning->{'text'} = parse_text_russian( $zero );

		$result->{'zero'} = $meaning;
	}

	while ( @lines > 0 ) {
		my $line = shift @lines;

		my $pale = 0;
		if ( $line eq '' ) {
			$pale = 1;
			$line = shift @lines;
		}

		my $meaning = new_dom_object('meaning');

		$meaning->{'text'} = parse_text_russian( $line );

		$meaning->{'pale'} = 1 if $pale;

		ref_push  $result->{'meanings'}, $meaning;
	}

	return $result;
}

sub parse_text_russian {
	my ($line) = @_;

	my $line_orig = $line;

	my $italic = 0; # Открытие-закрытие италика. Приходится протаскивать через парсер.

	my $res = "";
	if ( $line =~ s/^_//g) { # #1
		($line eq '') or fail "Removed '_' but line was expected to be empty.";
	}
	while ($line !~ /^\s*$/ ) {
		my $line_prev = $line;

		if ( $line =~ s/^\+\+// ) {
			# ++ означает, что строка занимает пространство слева. Пока не используется.

			$res .= atext_italic_stop(); # 2629
			$italic = 0;

			$res .= "\n";
		}
		elsif ( $line =~ s/^([\$\^\*][\d\?])(\d{4})// ) {
			# Что-то в ещё не отредактированной статье.
			#errmsg("? $1$2");
		}
		elsif ( $line =~ s/^(\@[\d\@])// ) { # сокращения
			my $abbr = $1;

			defined $abbreviations{$abbr} or fail "Unknown abbr: $abbr";

			$res .= " " if $res !~ /(^| )$/;
			$res .= atext_italic($abbreviations{$abbr});
			$res .= add_spaces( $res, $line );
		}
		else {
			$line =~ s/^_//; # #219
			($line, $res) = parse_text_common( $line, $res, \$italic );
		}

		$line_prev ne $line or fail "infinite loop: $line %% $line_orig";
	}

	if ( $italic ) {
		$res .= atext_italic_stop();
		$italic = 0;
	}

	return $res;
}

sub add_spaces {
	my ($res, $line) = @_;

	return " " if $line !~ /^([ \^\)\]\.,;\?!»]|$)/;

	return "";
}

sub parse_text_tango {
	my ($line, $rem_start, $word) = @_;
	$rem_start = '\^' if ! defined $rem_start;

	my $line_orig = $line;

	my $italic = 0; # Приходится протаскивать италик через весь разбор

	my $res = "";
	while ($line !~ /^\s*$/ ) {
		my $line_prev = $line;

		if ( $line =~ s/^(\*+)// ) { # начало частицы
			my $code = $1;

			$code =~ tr/\*/~/;

			$line = $code.$line; # вставляем обратно
		}
		elsif ( $line =~ m/^$rem_start/ ) { # remarks ^....

			($line, my $rem_obj) = parse_remark($line, $rem_start);

			$res .= " " if $res !~ /(^| )$/;
			$res .= " " if $res !~ /(^|  )$/;

			my $rem = "";

			if ( $rem_obj->{'code'} ) {
				my $code = $rem_obj->{'code'};
				defined $code_names{$code} or fail "Undefined code: '$code'";
				$rem .= $code_names{$code}.' ';
			}
			if ( defined $rem_obj->{'text'} ) {
				$rem .= $rem_obj->{'text'};
			}

			if ( defined $word ) {
				if ( $rem_obj->{'code'} eq '^@' ) { #  Чаще катаканой
					$word->{'force_katakana'} = 1;
				}
				elsif ( $rem_obj->{'code'} eq '^^' ) { #  Чаще хираганой
					$word->{'force_hiragana'} = 1;
				}
			}

			$res .= atext_colored('remark', $rem);

			$res .= add_spaces( $res, $line );
		}
		elsif ( $line =~ s/^\^(\d{4})// ) { # kanji ref
			$res .= make_kanji( $1 );
		}
		elsif ( $line =~ s/^\^"([^"]*)"// ) { # kana
			$res .= kana( $1 );
		}
		elsif ( $line =~ s/^([>@](\d+|[>]))// ) { # >1, >>, >23, @1
			my $abbr = $1;

			if ( $abbr eq '>>' ) {
				# '>>' - Имя собственное. В статьях не отображается.
			}
			else {
				$res .= " " if $res !~ /(^| )$/;
				defined $abbreviations{$abbr} or fail "Unknown abbr: '$abbr'";
				$res .= atext_italic( $abbreviations{$abbr} );
			}
		}
		else {
			($line, $res) = parse_text_common( $line, $res, \$italic );
		}

		$line_prev ne $line or fail "infinite loop: '$line' %% '$line_orig'";
	}

	if ( $italic ) {
		$res .= atext_italic_stop();
		$italic = 0;
	}

	return $res;
}

sub parse_text_common {
	my ($line, $res, $italic_ref) = @_;
	# $italic_ref - Открытие-закрытие италика. Приходится протаскивать через парсер.

	if ( $line =~ s/^\["([-\^=]?)([^\]]+)\]// ) { #  ["example"]
		my $mark = $1;
		my $txt = $2;

		$txt =~ s/"$//; # Убираем кавычку из конца строки (если есть)

		$txt =~ /^([\w \.,:;>\-\+'"]+)$/ or fail "strange brackets: '$txt'";

		$txt =~ s/>([a-z]+)>/[$1]/; # Такой вид задания скобок: >me> = [me]
		$txt !~ /[<>]/ or fail "Unmatching >..> brackets: '$txt'";

		if ( $mark eq '-' ) { # просто текст в кавычках
			$res .= '"'.cur_trans($txt).'"'; # здесь - обычные кавычки, будут заменены в другой ф-ии.
		}
		elsif ( $mark eq '^' ) { # от ...
			my $tmp = ' (от "'.cur_trans($txt).'")';
			$res .= atext_colored('example', $tmp);
		}
		elsif ( $mark eq '=' ) {
			my $tmp = ' (= "'.cur_trans($txt).'")';
			$res .= atext_colored('example', $tmp);
		}
		elsif ( $mark eq '' ) {
			my $tmp = ' ("'.cur_trans($txt).'")';
			$res .= atext_colored('example', $tmp);
		}
		else {
			fail "Unknown mark: '$mark'";
		}
		$res .= add_spaces( $res, $line );
	}
	elsif ( $line =~ s/^([0-9_ \-–\.,;:"'%№!\?\/…]+)// ) { #
		my $txt = $1;

		$txt =~ s/!!/\//g; #
		$txt =~ s/_/,/g; #

		# Добавляем пробелы после знаков препинания, если это не многоточие
		# и не конец строки
		# Вставляем не пробел, а <>, который потом будет заменён на пробел.
		# Это нужно, чтобы фиксить неправильно вставленные пробелы в числах.
		$txt =~ s/([\.,;\?!])(?!([ \-\^\)\]\.,;\?!»]|$))/$1<>/g;
		$txt =~ s/([\.,;\?!])$/$1<>/g if $line =~ /^[^\^#\)\]»]/;
		# Проверять #2876 輪

		# Фикс для запятых в числах. check #2713, #427, #430, #545 給, #917,
		# #985, #1187, #1877 兆
		while ( $line !~ /^и / && $txt =~ s/([\d]),<>(\d+)/$1,$2/g ) {};

		# Заменяем на пробелы.
		$txt =~ s/<>/ /g;

		$res .= $txt;
	}
	elsif ( $line =~ s/^([a-zа-яё]+)//i ) { # Просто текст
		my $txt = $1;
		
		if ( $line =~ s/^\(!(\d+)\)// ) { # Ударение
			my $pos = $1;
			#62 緯 '#текст.#уток(!3),уточная нить'  уто!к
			#82 芋 '#бот.#таро(!2),=Colocasia antiquorum'  та!ро
			#130 営 'ведение(!2) государства;'  ве!дение
			#172 猿 'трусы(!5)'  трусы!
			#253 過 'большая(!2) часть,большинство'  бо!льшая
			#521  '#мед.#бери(!2)-бери(!2),авитаминоз'
			#1084 子 'дама(!4),камка(!2)(узорчатая шёлковая ткань)'
			#2618 鱒
			#5311 蓼
			#6245 鶯
			
			substr($txt, $pos-1, 1) =~ /[аоуыэяюие]/
				or fail "Not a vowel under stress: ".substr($txt, $pos-1, 1)." '$txt'";

			substr( $txt, $pos, 0 ) = $stress_mark;
			
			fail "Double stress mark" if $line =~ /^\(!(\d+)\)/;
		}

		$res .= $txt;
	}
	# скобки
	elsif ( $line =~ s/^\(#// ) {
		$res .= " " if $res !~ /(^| )$/;
		$res .= "(";
	}
	elsif ( $line =~ s/^#\)// ) {
		$res .= ")";
		$res .= add_spaces( $res, $line );
	}
	elsif ( $line =~ s/^\(// ) {
		$res .= " " if $res !~ /(^| )$/;
		if ( !$$italic_ref ) {
			$res .= atext_italic_start();
			$$italic_ref++;
		}
		$res .= "(";
	}
	elsif ( $line =~ s/^\)// ) {
		$res .= ")";
		if ( $$italic_ref ) {
			$res .= atext_italic_stop();
			$$italic_ref = 0; # Сбрасываем! Не декремент.
		}
		$res .= add_spaces( $res, $line );
	}
	elsif ( $line =~ s/^#// ) {
		if ( !$$italic_ref && $line ne '' ) { # Не реагируем на италик в конце строки.
			$res .= " " if $res !~ /(^| )$/;
			$res .= atext_italic_start();
			$$italic_ref++;
		} else {
			$res .= atext_italic_stop();
			$$italic_ref = 0; # Сбрасываем! Не декремент.
			$res .= add_spaces( $res, $line );
		}
	}
	elsif ( $line =~ s/^\+// ) {
		$line =~ s/^_//; # #127,241,779,906,934,1617,1714,2119,2483,2503,2842,3123,...
		$res .= atext_italic_stop(); # 2629
		$$italic_ref = 0;

		$res .= "\n";
	}
	elsif ( $line =~ s/^~((~+|\+|\-|=)?(\d+|[\@=\+\-]))(\]?)// ) { # частицы
		my $code = $1;
		my $brackets = $4;

		defined $particles{$code} or fail "Unknown particle: '$code'";

		my $particle = $particles{$code};
		$particle = cur_trans( $particle ) if $particle ne '';

		if ( !$brackets ) {
			$particle = '~'.$particle unless ($code =~ /^-/);
			# Если код начинается с минуса -, то не нужно добавлять тильду ~
		}
		elsif ( $brackets eq '[' || $brackets eq ']' ) {
			$particle = '~['.$particle.']';
		}
		else {
			fail "particle: unknown bracket: '$brackets'";
		}

		$res .= " " if $res !~ /(^| )$/;
		$res .= atext_colored('particle', $particle);
		$res .= add_spaces( $res, $line );
	}
	elsif ( $line =~ s/^=([A-Z]([^\+\^\(\{\.;]|\(#)*)// ) { # lat.
		my $txt = $1;

		$line =~ /^([ \^\+\.;\{]|\([а-я]|$)/ or fail;
		$txt =~ /^([A-Za-z \+\-\^\(#\),!\/]+)$/ or fail;

		$txt = parse_text_russian ($txt);

		$res .= " " if $res !~ /(^| )$/;
		$res .= atext_colored('lat', $txt);
	}
	elsif ( $line =~ s/^{([^}]+)(?<!#)}// ) { # { .... }
		my $txt = $1;

		if ( $txt =~ s/^!// ) { # воскл. знак в начале - ?
			#errmsg "???? {!...}";
		}

		$txt =~ s/\(/(#/g; # Скобки внутри не означают италик
		$txt =~ s/\)/#)/g;

		$txt =~ s/  +/ /g; # Лишние пробелы

		!$$italic_ref or fail;
		my $tmp = parse_text_tango( $txt, '\^\^' );

		$res .= " " if $res !~ /(^| )$/;
		$res .= atext_colored('message', $tmp);
	}
	elsif ( $line =~ s/^([\[\]=~])// ) { # Просто текст - особые символы
		my $txt = $1;

		$res .= $txt;
	}

	return ($line, $res);
}

sub parse_tango_title {
	my ($line, $no_abr_italic) = @_;

	my $line_orig = $line;

	my $italic = 0;

	my $res = "";

	while ( $line !~ /^\s*$/ ) {
		my $line_prev = $line;

		if ( $line =~ s/^(\@[\dL\@])// ) {
			my $abbr = $1;

			defined $tan_title_abbrevs{$abbr}
				or fail "Unknown tan_title_abbrevs: '$abbr'";

			my $tmp = $tan_title_abbrevs{$abbr};

			if ( $tmp =~ /^</ ) { # <непродуктивно>
				$tmp = atext_pale ($tmp);
			} else {
				$tmp = atext_italic($tmp) unless $no_abr_italic;
			}

			$res .= " " if $res !~ /(^| )$/;
			$res .= $tmp;
		}
		elsif ( $line =~ s/^\((\d+)\)// ) { #  (1)
			my $n = int($1) - 1;

			if ( $italic ) { #432
				$res .= atext_italic_stop();
				$italic = 0;
			}

			my $tmp = format_kunref($n);

			$res .= " " if $res !~ /(^| )$/;
			$res .= atext_colored('kun_ref', $tmp);
		}
		elsif ( $line =~ s/^{([!]?)([^}]+)(?<!#)}// ) {
			my $code = $1;
			my $txt = $2;

			my $tmp = parse_text_tango( $txt, '\^\^' );

			$res .= " " if $res !~ /(^| )$/;
			$res .= $tmp;
		}
		elsif ( $line =~ s/^\[!(.*)\]// ) {
			my $txt = $1;
			# Check #82 芋, #894 腔, #1105 紫, #1146 鴫, #1521 星, ...
			# В оригинале этот текст исключается из выводимых в этом блоке
			# переводов составных слов. Не критично, м.б. сделаю в будущем.
			# TODO: ^
		}
		elsif ( $line =~ s/^\+// ) {
			# 2403 - италик не прерывается
			$res .= "\n";
		}
		elsif ( $line =~ s/^([\^\$]\d+)// ) { # ^12345
			# Check #4483 牀
			# Что-то в неотредактированных данных. Не отображается.
		}
		elsif ( $line =~ s/^\?// ) { # ???
			# ???
		}
		else {
			($line, $res) = parse_text_common( $line, $res, \$italic );
		}

		$line ne $line_prev
			or fail "Infinite loop: '$line' ne '$line_prev'";
	}

	if ( $italic ) {
		$res .= atext_italic_stop();
		$italic = 0;
	}

	return $res;
}

sub format_kunref {
	my ($n) = @_;

	my $objs = undef;
	if ( $n == -1 ) {
		# Check #75 磯
		@{$objects->{'kuns'}} >= 1 or fail;
		defined $objects->{'kuns'}->[0] or fail;
		ref($objects->{'kuns'}->[0]) eq 'HASH' or fail;
		$objs = [make_text_obj('tango_kun', $objects->{'kuns'}->[0]->{'main'})];
	} else {
		$objs = $objects->{'tango_kuns'}->[$n];
	}

	if ( ! defined $objs ) {
		errmsg("Wrong tango kun ref: (".($n+1).")");
		next;
	}

	my $tmp = "";

	# Format tango kuns:
	my @arr = ();
	foreach my $obj (@$objs) {
		my $tmp = "";
		if ( defined $obj->{'mod'} ) {
			my $mod = $obj->{'mod'};

			if ( $mod eq '_' ) {
				$tmp .= atext_italic("реже")." ";
			}
			else {
				fail "Unknown mod: '$mod'";
			}
		}

		my $tmp2 = cur_trans($obj->{'text'});
		if ( $romaji_or_kiriji ) {
			$tmp2 = "«".$tmp2."»";
		}
		$tmp .= $tmp2;
		push @arr, $tmp;
	}

	$tmp .= "(" . (join ", ", @arr) . ")";
	return $tmp;
}

sub parse_compounds {
	my ($compounds) = @_;

	return if !$compounds;

	# Format: 1:25309,1:6280,1:25303,2:15244,2:47805^,2:29870*,2:29867*,3:54021,3:25599,3:33422&

	# Ссылки на словарные статьи составных слов (Tango). 'N:' - номер пункта "в сочетаниях".
	# *) '^' в конце -  Нестандартное чтение.
	# *) '*' - Нестандартное значение
	# *) '&' - Нестандартное чтение и значение.

	my $res;

	$compounds =~ s/#//g;

	my @spl = split /,/, $compounds;

	foreach (@spl) {
		if ( /^(\d+|N):(\d+)([\^\*\&\@]?)$/ ) {
			# 1:5555^ - 1 номер пункта (N для имён),
			# 5555 - tango id, ^ или * - маркер (зелёный треугольник или красный ромб %)

			my $row_num = $1;
			my $tango_id = $2;
			my $marker = $3;

			my $comp_def_obj = new_dom_object('comp_def', 'Compound definition');
			$comp_def_obj->{'row_num'} = $row_num;
			$comp_def_obj->{'tango_id'} = $tango_id;
			$comp_def_obj->{'marker'} = $marker;

			ref_push  $res->{$row_num}, $comp_def_obj;
		}
		elsif ( /^(\d+|N):{(\d+)}$/ ) { # 2:{19}
			my $row_num = $1;
			my $msgid = $2;

			my $comp_def_obj = new_dom_object('comp_def', 'Compound definition');
			$comp_def_obj->{'row_num'} = $row_num;
			$comp_def_obj->{'tango_id'} = undef;
			$comp_def_obj->{'marker'} = '';
			$comp_def_obj->{'msgid'} = $2;

			ref_push  $res->{$row_num}, $comp_def_obj;
		}
		else {
			return $res if /^=/; # Служебные данные Яркси. Check #4742 碯, #5051 羃
			fail "parse_compounds: wrong chunk: '$_'"
		}
	}

	return $res;
}

sub parse_dicts {
	my ($dicts) = @_;

	# not used
}

sub parse_concise {
	my ($concise) = @_;

	# not used
}

sub parse_tango_kuns {
	my ($tango_kuns_chunk) = @_;

	defined $tango_kuns_chunk or fail;

	return if $tango_kuns_chunk eq "";

	foreach (split /\//, $tango_kuns_chunk) {
		ref_push $objects->{'tango_kuns'}, parse_tango_kun($_);
	}
}

sub parse_tango_kun {
	my ($line) = @_;

	my @res = ();

	while ( $line ne '' ) {
		my $line_prev = $line;

		if ( $line =~ s/^([_]?)([a-zA-Z: \-]+)// ) { # слово
			my $mod = $1;
			my $txt = $2;

			if ( $mod eq '-' ) {
				$txt = $mod.$txt;
				$mod = '';
			}

			my $tan_kun = make_text_obj('tango_kun', lc $txt);
			$tan_kun->{'mod'} = $mod if $mod;

			push @res, $tan_kun;
		}
		elsif ( $line =~ s/^\+// ) {
			# linefeed
		}
		elsif ( $line =~ s/^[,]// ) { # разделитель
			# Do nothing
		}

		$line ne $line_prev or fail "Inf loop: '$line'";
	}

	return \@res;
}

sub parse_tans {
	my ($tan_rows) = @_;

	my %tan_objs;

	foreach ( keys %$tan_rows ) {
		$tan_objs{$_} = parse_tan( $tan_rows->{$_} );
	}

	return \%tan_objs;
}

# Разбор танго (полный)
sub parse_tan {
	my ($tan_row) = @_;

	my $tan_obj; # результат

	$tan_obj->{'nomer'} = $tan_row->{'Nomer'};

	$tan_obj->{'word'} = parse_tan_word($tan_row);

	$tan_obj->{'readings'} = parse_tan_reading( $tan_row->{'Reading'} );

	if ( !$tan_row->{'K1'} && !$tan_row->{'K2'} && !$tan_row->{'K3'} && !$tan_row->{'K4'} ) {
		$tan_obj->{'no_kanji'} = 1;
	}

	$tan_obj->{'russian'} = parse_tan_rus( $tan_row->{'Russian'} );

	$tan_obj->{'force_katakana'} = 1 if $tan_obj->{'russian'}->{'force_katakana'};
	$tan_obj->{'force_hiragana'} = 1 if $tan_obj->{'russian'}->{'force_hiragana'};

	return $tan_obj;
}

# Разбор танго без разбора значения (для ссылок)
sub parse_tan_simple {
	my ($tan_row) = @_;

	my $tan_obj; # результат

	$tan_obj->{'word'} = parse_tan_word ($tan_row);

	$tan_obj->{'readings'} = parse_tan_reading( $tan_row->{'Reading'} );

	return $tan_obj;
}

# Разбор и построение самого слова
sub parse_tan_word {
	my ($tan_row) = @_;

	my @slot = ();

	$tan_row->{'K1'} and $slot[1] .= make_kanji( $tan_row->{'K1'} );
	$tan_row->{'K2'} and $slot[2] .= make_kanji( $tan_row->{'K2'} );
	$tan_row->{'K3'} and $slot[3] .= make_kanji( $tan_row->{'K3'} );
	$tan_row->{'K4'} and $slot[4] .= make_kanji( $tan_row->{'K4'} );

	if ( $tan_row->{'Kana'} ) {
	# Форматтер составного слова
		my $kana_orig = my $kana = $tan_row->{'Kana'};
		my $pos = 4; # Позиция для вставки. По умолчанию - в конец.
		my $type = ''; # unknown
		while ( $kana !~ /^\s*$/ ) {
			my $kana_prev = $kana;

			if ( $kana =~ s/^([\d])// ) { # номер слота 0-7
				# Слот 7: Tango: 1ha3to4uyori#2173#5ro#1111##1455#7da;
				$pos = $1;
			}
			elsif ( $kana =~ s/^([\^\@])// ) {
				my $kanatypech = $1;
				if ( $kanatypech eq '^' ) {
					$type = 'katakana';
				}
				elsif ( $kanatypech eq '@' ) {
					$type = 'hiragana';
				}
			}
			elsif ( $kana =~ s/^([a-zA-Z:'\(\)\[\]\-]+)// ) { # кана
				# -  в Tango: Kana: desu-edyuke:shon
				my $txt = $1;

				$txt =~ s/'($|\))/t_/g; # ' означает маленькое цу
				# Но также ' означает "твёрдый знак". n'a
				# Tango:  ka:ten'wo:ru
				$txt !~ /'[^aouieyw]/  # n'a is ok. n'[^aouiey] is strange
					 or fail "$txt";


				$txt !~ /ye/  # означает маленькое цу в других местах
					or fail;

				$txt =~ s/qi/$iteration_mark/g;

				$txt = uc $txt if $type eq 'katakana';

				$slot[$pos] .= kana( $txt, $type );
			}
			elsif ( $kana =~ s/^#(\d{2,4})#// ) { # дополнительный кандзи (#4)
				my $kanji_id = $1;
				# Добавляем в конец!
				$slot[ @slot ] .= make_kanji( $kanji_id );
			}
			else {
				fail "Wrong kana: '$kana' ('$kana_orig') in tango ".$tan_row->{'Nomer'};
			}

			$kana ne $kana_prev or fail;
		} # end of while
	}
	my $word = "";

	foreach ( 0..10 ) {
		$word .= $slot[$_] if $slot[$_];
	}
	!defined $slot[11] or fail;
	# Слот 8: Tango: ippammeireienzankiko: #167##1061##471##875#
	# Слот 9: Tango: genkinjido:yokinshiharaiki #2760##630##1091##2451##471#
	# Слот 10: Tango: cho:semminshushugijimminkyo:wakoku #1199##503##1455##2649##570##2948#

	return $word;
}

sub parse_tan_reading {
	my ($line) = @_;

	return if !$line;

	$line =~ s/^\*//;

	$line =~ s/\*\*/_*/g; # заменяю ** на _*

	my @readings = split /\*/, $line;

	my @res = ();

	foreach ( @readings ) {
		my $pale = 0;
		$pale = 1 if s/_$//;

		s/\^//g; # FIX ^ e.g. Tango: Reading: shoku^pan;

		push @res, make_text_obj('reading', $_, 'pale'=>$pale);
	}

	return \@res;
}

sub parse_tan_rus {
	my ($tan_rus) = @_;

	return if !$tan_rus;

	my $result = new_dom_object('tan_rus');

	# ! в начале означает неотредактированные данные
	$result->{'pale'} = 1 if ( $tan_rus =~ s/^!// );

	my @lines;

	@lines = split '&', $tan_rus;

	my $zero = shift @lines;

	if ( defined $zero && $zero ne '' ) {

		my $meaning = new_dom_object('meaning');
		$meaning->{'text'} = parse_text_tango( $zero, undef, $result ); # parse

		$result->{'zero'} = $meaning;
	}

	while ( @lines > 0 ) {
		my $line = shift @lines;

		my $pale = 0;
		if ( $line eq '' ) {
			$pale = 1;
			$line = shift @lines;
		}

		my $meaning = new_dom_object('meaning');
		$meaning->{'text'} = parse_text_tango( $line, undef, $result ); # parse
		$meaning->{'pale'} = 1 if $pale;

		ref_push  $result->{'meanings'}, $meaning;
	}

	return $result;
}


# Разбор ромадзи с сохранением в "универсальный" формат.
# Универсальный формат, из которого можно без дополнительного анализа
# получить запись каной. Из него проще сделать и любую другую транскрипцию.
sub parse_kana {
	my ($txt, $type) = @_;

	my $txt_orig = $txt;

	my $res = new_dom_object('kana');
	$res->{'type'} = $type if defined $type;

	my @res = ();
	my $s = '';

	while ( 1 ) {
		my $txt_prev = $txt;

		if ( $txt =~ s/^(.)// ) {
			$s .= $1;
		} else {
			push @res, $s  if $s ne '';
			last;
		}

		if ( $s =~ /^[^a-zA-Z:]$/ ) { # other symbols
			push @res, $s; $s = ''; next;
		}
		if ( $s =~ /^[aueo:]$/i ) {
			push @res, $s; $s = ''; next;
		}
		if ( $s =~ /^i$/i ) {
			if ( $txt =~ s/^:// ) {
				push @res, $s.$s; $s = ''; next;
			}
			push @res, $s; $s = ''; next;
		}
		if ( $s =~ /^[ksnmrgzbp][aueo]$/i ) {
			push @res, $s; $s = ''; next;
		}
		if ( $s =~ /^([knhmrgjbp]|sh|ch)i$/i ) {
			push @res, $s; $s = ''; next;
		}
		if ( $s =~ /^(tsu|ti|tso|si|je|[fh]y?[aiueo])$/i ) {
			push @res, $s; $s = ''; next;
		}
		if ( $s =~ /^(y[auo]|w[aoe]|j[auo]|[td][aeo])$/i ) {
			push @res, $s; $s = ''; next;
		}
		if ( $s =~ /^(du|di|dyu)$/i ) { # =/
			push @res, $s; $s = ''; next;
		}
		if ( $s =~ /^[knhmrgbpv]y[auo]$/i ) {
			push @res, $s; $s = ''; next;
		}
		if ( $s =~ /^(sh|ch)[eauo]$/i ) {
			push @res, $s; $s = ''; next;
		}
		if ( $s =~ /^(n|m)(.)$/i ) {
			my $n = $1;
			my $b = $2;

			$n =~ tr/mM/nN/;

			next if ( $b =~ /^y$/i ); # nya ^__^

			if ( $b eq "'" ) { # n'
				push @res, "$n'"; $s = ''; next;
			}

			push @res, $n; $txt = $b.$txt; $s = ''; next;
		}
		if ( $s =~ /^(n|m)$/i && $txt eq '' ) {  # trailing 'n'
			$s =~ tr/mM/nN/;
			push @res, $s; $s = ''; next;
		}
		if ( $s =~ /^(va)$/i ) { # 'va' means 'ha' is readed as 'wa'
			push @res, $1; $s = ''; next;
		}
		if ( $s =~ /^(v[iueo]|wi|ty?u)$/i ) { # извращенская катакана
			push @res, $1; $s = ''; next;
		}
		if ( $s =~ /^(v)(r)$/i ) { # PAVROFU
			push @res, $1; $s = $2; next;
		}
		if ( $s =~ /^(([kstpfdgjzbh])[\)\]]*\2|tch)$/i ) { # double
			if ( $s=~ /^[a-z]/ ) {
				push @res, 't_';  # маленькое цу - символ удвоения согласной
			}
			elsif ( $s=~ /^[A-Z]/ ) {
				push @res, 'T_';  # маленькое цу (катакана)
			}
			$s =~ s/^.//; $txt = $s.$txt; $s = '';
			next;
		}
		if ( $s =~ /^(t_|qe)$/i ) { # маленькое цу, маленькое КЕ
			push @res, $1; $s = ''; next;
		}
		if ( $s =~ /^s$/i && $txt =~ /^( |$)/ ) { # su редуцированное до s как в desu
			push @res, $s.'_'; $s = ''; next;
		}

		$txt_prev ne $txt or fail "Infinite loop";
	}

	$s eq '' or fail "romaji parse: tail: $s;";

	add_child $res, @res;

	return $res;
}

1;
