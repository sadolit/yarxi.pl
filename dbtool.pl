#!/usr/bin/perl

# Yarxi.PL - Консольный интерфейс к словарю Yarxi.
# Вспомогательный интерфейс для просмотра базы данных в исходном виде.
# 
# Оригинальная программа (Яркси) и база данных словаря - (c) Вадим Смоленский.
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
use Encode;


my $db_filename = 'yarxi_u.db';
my $table = 'Kanji';
my $column = 'Russian';    
my $row = '';

if ( @ARGV == 4 ) {
    $db_filename = $ARGV[0];
    $table = $ARGV[1];
    $column = $ARGV[2];
    $row = $ARGV[3];
}
if ( @ARGV == 3 ) {
    $db_filename = $ARGV[0];
    $table = $ARGV[1];
    $column = $ARGV[2];
}
if ( @ARGV == 2 ) {
    $table = $ARGV[0];
    $column = $ARGV[1];
}
elsif ( @ARGV == 1 ) {
    $column = $ARGV[0];    
}

if ( $column =~ /^\d+$/ ) {
    $row = $column;
    $column = '';
}

# Extract the program directory
my $dirref = $0;
$dirref =~ s/\/[^\/]*$/\//;

$| = 1;

my $dbi_path = "dbi:SQLite:dbname=${dirref}${db_filename}";
my $dbh;

$dbh = DBI->connect($dbi_path,"","");

my $sql;
if ( $column ne '' ) {
    if ( $row ne '' ) {
        $sql = "SELECT $column FROM $table LIMIT $row-1,1;";
    } else {
        $sql = "SELECT $column FROM $table;";
    }
} else {
    $sql = "SELECT * FROM $table LIMIT $row-1,1;";
}

my $sth = $dbh->prepare ($sql);

$sth->execute();

while ( my $row = $sth->fetchrow_hashref ) {
    foreach (keys %$row) {
        print "$_: " if ( keys %$row > 1 );
        my $val = decode_utf8($row->{$_});
        
        print encode_utf8($val).";\n";
    }
}
    
exit 0;
