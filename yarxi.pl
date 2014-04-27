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
use utf8;
use FindBin;

sub BEGIN {
	unshift @INC, $FindBin::Bin;

	$| = 1; # Препятствуем кэшированию вывода.
}

use JDCommon;
use JDFormatter;
use JDPrinterC;
#----------------------------------------------------------------------

sub say($) {
	my ($txt) = @_;

	utf8::encode($txt);

	print $txt;
}

sub article {
	my ($num) = @_;
	( $num eq int($num) ) or fail;

	JDCommon::cleanup();

	# Формирование статьи
	my $document = format_article($num);
	if ( !$document ) { # Нет такой статьи
		return "";
	}

	# "Рендеринг" статьи
	my $out = print_article($document);

	$document = undef; # Удаляем объекты

	return $out; # Отправляем в output
}

sub tango_alone {
	my ($num) = @_;

	( $num ) or fail;
	( $num eq int($num) ) or fail;

	JDCommon::cleanup();

	# Формирование статьи
	my $document = format_tango_alone($num);
	if ( !$document ) { # Нет такой статьи
		return "";
	}

	# "Рендеринг статьи" - вывод её в определённом представлении.
	my $out = print_object($document);
	$out .= "\n";

	return $out; # Отправляем в output
}

sub do_test {
	my ($start) = @_;

	open STDOUT, ">/dev/null";

	my $start_time = time();
	my $i = $start;
	while ( 1 ) {
		eval {
			while ( 1 ) {
				# DBG:
				print STDERR ".";
				print STDERR "  $i\n" if ( $i % 1000 == 0 );
				my $tmp = article($i) or die "No more articles.";
			}
			continue {$i++}
		};
		if ($@) {
			my $res = '';
			while  ($res !~ /^[yn]$/i ) {
				#exit 0; # DBG:

				print STDERR "\n>>$i<<\n";
				print STDERR "$@\n";
				print STDERR "Continue?(y/n) ";

				$res = getc();
			}
			last if ( $res =~ /^[n]$/i );
		}
	}
	continue {$i++}

	print STDERR "\nDone in ".(time - $start_time)." seconds.\n";
}

sub do_test2 {
	my ($start) = @_;

	open STDOUT, ">/dev/null";

	my $i = $start;
	while (1) {
		eval {
			while ( 1 ) {
				# DBG:
				print STDERR ".";
				print STDERR "  $i\n" if ( $i % 1000 == 0 );
				my $tmp = tango_alone($i) or die "No more articles";
			}
			continue {$i++}
		};
		if ($@) {
			my $res = '';
			while  ($res !~ /^[yn]$/i ) {
				print STDERR "\n>>$i<<\n";
				print STDERR "$@\n";
				#last if $i == 45252;
				#exit 0; # DBG:

				print STDERR "Continue?(y/n) ";
				$res = getc();
			}
			last if ( $res =~ /^[n]$/i );
		}

	}
	continue {$i++}

	print STDERR "\nDone.\n";
}

# Пока не используется
sub get_term_width {
	my $res;

	# Проверяем, есть ли утилита tput
	$res = system('which tput >/dev/null 2>&1');
	return undef if $res != 0;

	my $cols = `tput cols`;
	return undef if $? != 0;

	chomp $cols;

	return $cols;
}
#----------------------------------------------------------------------

# Поиск

sub search_lat {
	my ($txt) = @_;

	# Точный поиск в Kanji
	my $res = search_kunyomi($txt);
	if ( $res && @$res ) {
		return kanji_results($res);
	}

	# Точный поиск в Tango
	$res = search_tango_reading($txt);
	if ( $res && @$res ) {
		return tango_results($res);
	}

	return '';
}

sub search_rus {
	my ($txt) = @_;

	# Точный поиск в Kanji.RusNick
	my $res = search_kunyomi_rusnick($txt);
	if ( $res && @$res ) {
		return kanji_results($res);
	}

	# Неточный поиск в Kanji.Russian
	$res = search_kunyomi_russian($txt);
	if ( $res && @$res ) {
		return kanji_results($res);
	}

	# Неточный поиск в Tango.Russian
	$res = search_tango_russian($txt);
	if ( $res && @$res ) {
		return tango_results($res);
	}

	return '';
}

sub kanji_results {
	my ($kanjis) = @_;
	my $out = '';

	my $max_other = 100;

	my $first = $kanjis->[0];
	$out .= article( $first->[0] );
	if ( @$kanjis > 1 ) {
		$out .= "\nТакже найдено в статьях: ";
		for (my $i=1; $i < $max_other && $i < @$kanjis; $i++ ) {
			$out .= chr(($kanjis->[$i])->[1])." ";
		}
		if ( @$kanjis > $max_other ) {
			$out .= " плюс ещё ".int(@$kanjis - $max_other)." статей...";
		}
		$out .= "\n";
	}

	return $out;
}

sub sort_tango_results {
	my ($ids, $grep) = @_;

	my %results = ();
	foreach my $num ( @$ids ) {
		my $tango_obj = JDFormatter::parse_tan(fetch_tango_full($num));
		my $tmp = JDPrinterC::print_object($tango_obj->{'word'});
		$tmp =~ s/\Q$grep\E//; # Чем лучше совпадение, тем ближе к началу
		push @{$results{length($tmp)}}, $num;
	}
	return [map @{$results{$_}}, sort {$a<=>$b} keys %results];
}

sub tango_results {
	my ($ids) = @_;
	my $out = "";

	my $max_i = scalar(@$ids);
	if ( !$search_show_all && $max_i > 25 ) {
		$max_i = 25;
	}
	for ( my $i = 0; $i < $max_i; $i++ ) {
		$out .= tango_alone($ids->[$i]);
	}
	if ( scalar(@$ids) > $max_i ) {
		$out .= "\n... плюс ещё ".(scalar(@$ids) - $max_i)." слов."
			." Используйте ключ -a, чтобы увидеть все найденные результаты.\n";
	}

	return $out;
}

#----------------------------------------------------------------------

sub kana_table {
	my $res = <<HEREDOC;
 ва  ра   я  ма  ха  на  та  са  ка   а
 わ  ら  や  ま  は  な  た  さ  か  あ - а
  н  り   ю  み  ひ  に  ち  し  き  い - и
 ん  る  ゆ  む  ふ  ぬ  つ  す  く  う - у
  о  れ   ё  め  へ  ね  て  せ  け  え - э
 を  ろ  よ  も  ほ  の  と  そ  こ  お - о

          я    ба па    да   дза  га  а
 ゎ      ゃ    ば ぱ    だ   ざ  が  ぁ - а
 ゐ       ю    び ぴ    ぢ   じ  ぎ  ぃ - и
 ゑ      ゅ    ぶ ぷ   っづ  ず  ぐ  ぅ - у
 ゝ       ё    べ ぺ    で   ぜ  げ  ぇ - э
 ゞ      ょ    ぼ ぽ    ど   ぞ  ご  ぉ - о
-------------------------------------------
 ВА  РА   Я  МА  ХА  НА  ТА  СА  КА   А
 ワ  ラ  ヤ  マ  ハ  ナ  タ  サ  カ  ア - А
  Н  リ   Ю  ミ  ヒ  ニ  チ  シ  キ  イ - И
 ン  ル  ユ  ム  フ  ヌ  ツ  ス  ク  ウ - У
  О  レ   Ё  メ  ヘ  ネ  テ  セ  ケ  エ - Э
 ヲ  ロ  ヨ  モ  ホ  ノ  ト  ソ  コ  オ - О
-------------------------------------------
 ヮ       Я    БА ПА    ДА   ДЗА ГА   А
 ヰ      ャ    バ パ    ダ   ザ  ガ  ァ - А
 ヱ       Ю    ビ ピ    ヂ   ジ  ギ  ィ - И
 ヴ      ュ    ブ プ   ッヅ  ズ  グ  ゥ - У
 ヵ       Ё    ベ ペ    デ   ゼ  ゲ  ェ - Э
 ヶ      ョ    ボ ポ    ド   ゾ  ゴ  ォ - О

HEREDOC

	#my $start = ord("あ")-3;
	#for ( my $i=$start; $i <  $start+200; $i++ ) {
		#$res .= "(".chr($i).") - $i\n";
	#}
	return $res;
}

my @radicals;
$radicals[1] = [qw/丨 丶 一 ´ 丿 乀 L 乙 乚 亅 ᒣ ㄑ フ ㄅ/];
$radicals[2] = [qw/亻 冫 十 刂 刀 力 勹 匕 七 九 又 二 厂 人 ⋏ 八 亠 冖 冂 厶 儿 氾 卩 入 几 凵 匚 了 乃 ㄎ ˫ 卜 ⊤ 丁 乂 〤 ヌ ユ/];
$radicals[3] = [qw/彳 氵 扌 艹 阝 囗 口 忄 女 子 弓 工 广 尸 大 辶 土 士 宀 上 夂 山 己 寸 夕 久 ヨ 巾 干 千 弋 万 彡 及 廴 后 犭 下 亡 于 丈 小 乇 廾 ㄐ 幺 兀 尢 丸 刃 刄 巛 川 丬 也 彐 彑 屮 才 巳 ㅌ 叉 凡 与 之/];
$radicals[4] = [qw/木 欠 火 灬 日 月 斤 心 礻 殳 王 壬 戸 尺 中 气 止 攵 开 井 歹 ヰ 尹 帀 午 牛 戈 方 手 丰 比 毛 犬 不 云 文 少 屯 夬 夫 天 夭 予 六 元 尤 爪 氏 升 内 毋 水 氶 爿 片 五 互 廿 勿 牙 太 巴 円 E 斗 丐 反 友 支 攴 丹 曰 匁 丑 弔 父 乏/];
$radicals[5] = [qw/禾 矢 失 穴 白 目 且 罒 皿 衤 玉 疒 石 右 业 生 巨 正 立 出 用 田 由 申 甲 甩 布 市 乍 左 戊 戉 主 疋 史 癶 圥 去 弗 以 本 示 尓 瓜 氐 民 央 未 末 玄 矛 半 平 乎 冊 丙 母 氺 永 丘 冉 必 世 丗 甘 旡 匆 皮 古 占 凸 凹 术 北 斥 瓦/];
$radicals[6] = [qw/糸 行 朱 竹 米 自 耳 舌 血 舟 虫 羽 羊 虍 寺 臼 圭 朿 西 襾 共 色 艮 早 聿 当 有 曲 年 缶 成 戍 耒 此 向 吏 先 至 夷 交 衣 死 曳 亦 夹 亥 囟 并 光 而 肉 毎 兆 州 両 再 产 百 卍/];
$radicals[7] = [qw/言 車 貝 見 釆 来 足 身 辛 镸 辰 豆 豕 呆 束 臣 酉 亜 肖 角 良 甫 里 男 乕 我 別 求 走 更 豸 告 系 弟 余 赤 夾 卵 那 囱 兌 克 呂 串 局 呉 兵/];
$radicals[8] = [qw/金 卓 門 雨 來 隹 非 幸 長 物 垂 並 果 東 事 歩 亞 其 免 斉 妻 隶 典 罔 岡 武 制 実 夜 尚 画 尭 表 舍 承 鼡/];
$radicals[9] = [qw/食 革 頁 首 風 禹 禺 韭 面 飛 咼 韋 乗 為 重 柬 酋 甚 奐 音 某 単 卑 爰 南 段 美 前 発 負 貞 盾 県 衷 茶 畏 /];
$radicals[10] = [qw/馬 鳥 魚 鬼 番 歯 婁 髟 弱 骨 鹿 龍 畢 業 善 黽 龜 冓 奥 齊 楽 黒 巣 兼 粛 爾 黍 烏 殷 象 鬥 黄 寅 賁 鹵 第 鼎 衰 倉 喪 益/];
#----------------------------------------------------------------------

sub about {
	return <<HEREDOC;
Yarxi.PL - 2007-2010 (c) Андрей Смачёв aka Biga.

Консольный интерфейс к словарю Yarxi.

Оригинальная программа (Яркси) и база данных словаря - (c) Вадим Смоленский.
(http://www.susi.ru/yarxi/)
HEREDOC
}
#----------------------------------------------------------------------

sub print_help {
	say about();

	say <<HEREDOC;

Использование:
yarxi.pl [опция] [что искать] [-a]

Слово для поиска может быть:
* Числом, например 1234. Тогда будет показана статья с этим номером.
* Слово латинскими буквами. Будет произведён поиск в транскрипциях
   (кунъёми и составные слова).
* Слово русскими буквами. Будет искаться в "базовых значениях" иероглифов,
   значениях кунъёми и составных слов.
* Единичный иероглиф. Будет осуществлён поиск соответствующей статьи.
* Слово на японском. Кана будет проигнорирована. Из слова будут выделены
   иероглифы, и будет произведён поиск составных слов, содержащих
   все эти иероглифы без учёта порядка.

В слове для поиска можно использовать символ подчёркивания "_" для
обозначения произвольного (неизвестного) символа и символ процента
"%" для обозначения произвольного (в т. ч. и нулевого) числа любых
символов. Т. е. это обычная нотация оператора LIKE языка SQL.
Также, точки "." в начале и конце слова означают то же, что и "%"
(как в Яркси).

Опции:
   Там, где написано <aiueo>, подразумевается слово для поиска, записанное
   латинскими буквами. <абв> - соответственно, русскими.
   Если хотите искать что-либо с пробелами, заключайте словосочетание
   в кавычки (" или '). Например, "несколько слов".

  -a            Выводить при поиске все найденные значения. По-умолчанию
                 выводится только ограниченное число значений, если найдено
                 слишком много всего.
  -co  <KANJI>  Поиск составных слов по набору иероглифов без учёта порядка.
  --help, -h    Показ этой справки.
  -kr  <абв>    Поиск по значениям кунъёми.
  -kun <aiueo>  Поиск иероглифов с кунъёми "aiueo".
  -on  <aiueo>  Поиск иероглифов с онъёми "aiueo".
  -ru  <абв>    Поиск по "базовым значениям" иероглифов, значениям
                 кунъёми и составных слов.
  -rn  <абв>    Поиск только по "базовым значениям" иероглифов.
  -t   <NUM>    Показ составного слова с номером NUM в базе данных.
  -tan <aiueo>  Поиск составных слов по чтению.
  -tr  <абв>    Поиск в значениях составных слов.
  -u   <NUM>    Поиск иероглифа по его коду в юникоде.

  -r [радикалы] Поиск по радикалам.
                Вызовите 'yarxi.pl -r' чтобы увидеть таблицу радикалов.
  -R <KANJI>    Разбить иероглиф на радикалы (глубокое разбиение).

Дополнительные опции:

  test          Генерация всех словарных статей в целях отладки.
  test2         Генерация всех составных слов, также в целях отладки.

  kanatable     Таблица хираганы и катаканы.

  --width <n>   Ширина выводимого текста.

HEREDOC
}

sub Init {
	# Читаем конфиги
	my $config = read_config();

	if ( $config->{'cur_trans_type'} ) {
		JDFormatter::set_cur_trans_type( $config->{'cur_trans_type'} );
	}
	if ( $config->{'scheme'} ) {
		my ($colors, $pale_map) = read_colorscheme_file( $config->{'scheme'} );
		JDPrinterC::set_color_map($colors, $pale_map);
	}
	if ( $config->{'italic'} ) {
		$JDPrinterC::use_italic = 1;
	}
	if ( $config->{'term_width'} ) {
		$JDPrinterC::term_width = $config->{'term_width'};
	} else {
		$JDPrinterC::term_width = get_term_width();
	}
}

#----------------------------------------------------------------------

### BEGIN ###

Init();

# Parse cmdline parameters
if ( @ARGV == 0 ) {
	say about();
	say "\nДля просмотра возможностей, используйте опцию '--help'\n\n";
}
my @args = @ARGV;
utf8::decode($_) foreach @args;

# Читаем аргументы в два прохода
# В первом ищем флаги
foreach my $arg ( @args ) {
	if ( $arg eq "-a" ) {
		$search_show_all = 1;
	}
}

while ( my $arg = shift @args ) {

	if ( $arg eq '--help' || $arg eq '-h' ) {
		print_help();
	}
	elsif ( $arg eq '--width' ) {
		$JDPrinterC::term_width = int(shift @args);
	}
	elsif ( $arg eq '-t' ) { # Tango
		$arg = shift @args;

		$arg eq int($arg) or fail "Should be numeric: '$arg'";

		say tango_alone( $arg ) or say "Нет такой статьи (Tango $arg)\n";
	}
	elsif ( $arg eq '-on' ) {
		my $res = search_onyomi(shift @args);
		if ( $res && @$res ) {
			say kanji_results($res);
		} else {
			say "Ничего не найдено.\n";
		}
	}
	elsif ( $arg eq '-kun' ) {
		my $res = search_kunyomi(shift @args);
		if ( $res && @$res ) {
			say kanji_results($res);
		} else {
			say "Ничего не найдено.\n";
		}
	}
	elsif ( $arg eq '-tan' ) {
		my $res = search_tango_reading(shift @args);
		if ( $res && @$res ) {
			say tango_results($res);
		} else {
			say "Ничего не найдено.\n";
		}
	}
	elsif ( $arg eq '-co' ) {
		my $res = search_compound(shift @args);
		if ( $res && @$res ) {
			say tango_results($res);
		} else {
			say "Ничего не найдено.\n";
		}
	}
	elsif ( $arg eq '-tr' ) {
		my $res = search_tango_russian(shift @args);
		if ( $res && @$res ) {
			say tango_results($res);
		} else {
			say "Ничего не найдено.\n";
		}
	}
	elsif ( $arg eq '-rn' ) {
		my $res = search_kunyomi_rusnick(shift @args);
		if ( $res && @$res ) {
			say kanji_results($res);
		} else {
			say "Ничего не найдено.\n";
		}
	}
	elsif ( $arg eq '-kr' ) {
		my $res = search_kunyomi_russian(shift @args);
		if ( $res && @$res ) {
			say kanji_results($res);
		} else {
			say "Ничего не найдено.\n";
		}
	}
	elsif ( $arg eq '-ru' ) {
		say search_rus( shift @args ) or say "Ничего не найдено.\n";
	}
	elsif ( $arg =~ /^--tran(?:\=(.*))?$/ ) {
		my $arg = ($1 or shift @args);
		JDFormatter::set_cur_trans_type( $arg );
	}
	elsif ( $arg eq '-u' ) {
		$arg = shift @args;
		defined $arg && $arg =~ /^\d+$/
				or fail "Ключ -u ожидает число после себя.";
		search_unicode( $arg ) or say "Ничего не найдено (".chr($arg)." - $arg).\n";
	}
	elsif ( $arg eq 'test' ) {
		my $start = shift @args;
		$start = 1 if !defined $start;
		do_test($start);
	}
	elsif ( $arg eq 'test2' ) {
		my $start = shift @args;
		$start = 1 if !defined $start;
		do_test2($start);
	}
	elsif ( $arg eq 'colormap' ) {
		print colors_table();
	}
	elsif ( $arg eq 'kanatable' ) {
		print kana_table();
	}
	elsif ( $arg =~ /^\d+$/ ) {
		say article($arg) or say "Нет такой статьи: $arg\n";
	}
	elsif ( $arg =~ /^[%\.a-z:]/i ) {
		say search_lat($arg) or say "Ничего не найдено.\n";
	}
	elsif ( $arg =~ /^[%\.а-яё]/i ) {
		say search_rus($arg) or say "Ничего не найдено.\n";
	}
	elsif ( $arg =~ /^([一-龥])$/ ) {
		my $uncd = ord($1);
		my $nomer = search_unicode($uncd);
		if ( $nomer ) {
			say article($nomer) or say "Нет такой статьи: $arg\n";
		} else {
			say "Не найдено статьи для знака '$arg' код $uncd.\n";
		}
	}
	elsif ( $arg =~ /[一-龥]/ ) {
		my $res = search_compound($arg);
		$res = sort_tango_results($res, $arg);
		if ( $res && @$res ) {
			say tango_results($res);
		} else {
			say "Ничего не найдено.\n";
		}
	}
	elsif ( $arg eq '-r' ) {
		if ( !@args ) {
			say "Радикалы:\n";
			for ( my $i = 1; $i <= $#radicals; $i++ ) {
				my $rads = $radicals[$i];
				say join " ", "$i:", @$rads, "\n";
			}
		} else {
			my @rads = ();
			while ( @args && $args[0] !~ /^-/ ) {
				push @rads, split //, shift @args;
			}
			say search_rads(@rads) or say "Ничего не найдено.\n";
		}
	}
	elsif ( $arg eq '-R' ) {
		$arg = shift(@args);
		if ( $arg =~ /^[一-龥]$/ ) {
			say split_kanji($arg) or say "Ничего не найдено.\n";
		} else {
			say "Ожидается иероглиф после -R.";
		}
	}
	elsif ( $arg =~ /^-(a)$/ ) {
		# Do nothing
	}
	else {
		errmsg ("Непонятный параметр: '$arg'");
		if ( $arg =~ /^.$/ ) {
			errmsg ("'$arg' - ".ord($arg));
		}
	}
}

exit 0;
