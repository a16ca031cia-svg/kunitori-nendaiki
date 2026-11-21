#!/usr/bin/perl
# フォントに残す文字の一覧を作る：プロジェクトの文章に出てくる全部の文字＋かな＋JIS第1水準の漢字＋記号・英数字
use strict; use warnings; use utf8; use Encode;
binmode STDOUT, ':encoding(UTF-8)';
my %c;
my @files = map { glob $_ } ("core_src/*.gd", "scripts/*.gd", "scripts/ui/*.gd", "data/*.json");
for my $f (@files) {
	open my $h, '<:encoding(UTF-8)', $f or next;
	local $/; my $s = <$h>; close $h;
	$c{$_} = 1 for split //, $s;
}
for my $r ([0x20, 0x7E], [0xA0, 0xFF], [0x2000, 0x206F], [0x2190, 0x21FF], [0x2200, 0x22FF], [0x2460, 0x24FF], [0x2500, 0x257F], [0x25A0, 0x25FF], [0x2600, 0x26FF], [0x3000, 0x303F], [0x3040, 0x309F], [0x30A0, 0x30FF], [0x31F0, 0x31FF], [0xFF00, 0xFFEF]) {
	$c{chr($_)} = 1 for $r->[0] .. $r->[1];
}
# JIS第1水準の漢字（Shift_JIS 0x889F〜0x9872）
for my $hi (0x88 .. 0x98) {
	for my $lo (0x40 .. 0xFC) {
		next if $lo == 0x7F;
		my $code = $hi * 256 + $lo;
		next if $code < 0x889F or $code > 0x9872;
		my $u = eval { Encode::decode("shiftjis", pack("CC", $hi, $lo), Encode::FB_CROAK) };
		$c{$u} = 1 if defined $u and length $u == 1;
	}
}
delete $c{"\n"}; delete $c{"\r"}; delete $c{"\t"};
print join('', sort keys %c);
