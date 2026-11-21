#!/usr/bin/perl
# TrueType フォントの「使う文字だけ」を残す（ほかの字形は空にする）簡単な道具
#   perl tools/subset_font.pl 元.ttf 出力.ttf 文字の一覧.txt
# - 文字の一覧（UTF-8）に含まれる文字と、合成字形が使う部品の字形だけを残す
# - glyf と loca を作り直し、DSIG（署名）は外す。ほかの表はそのまま
use strict;
use warnings;
use utf8;

my ($src, $dst, $listf) = @ARGV;
die "使い方: subset_font.pl 元.ttf 出力.ttf 文字.txt\n" unless $listf;

open my $fh, '<:raw', $src or die "$src: $!";
local $/;
my $font = <$fh>;
close $fh;

open my $lh, '<:encoding(UTF-8)', $listf or die "$listf: $!";
my $chars = <$lh>;
close $lh;
my %want;
$want{ord($_)} = 1 for split //, $chars;

my ($ver, $numT) = unpack('Nn', substr($font, 0, 6));
my %T;
my @order;
for my $i (0 .. $numT - 1) {
	my ($tag, $sum, $off, $len) = unpack('a4NNN', substr($font, 12 + 16 * $i, 16));
	$T{$tag} = [$off, $len];
	push @order, $tag;
}
sub tbl { my $t = shift; return substr($font, $T{$t}[0], $T{$t}[1]); }

my $head = tbl('head');
my $locFmt = unpack('n', substr($head, 50, 2));
my $numGlyphs = unpack('n', substr(tbl('maxp'), 4, 2));
my $loca = tbl('loca');
my @loc;
for my $g (0 .. $numGlyphs) {
	push @loc, $locFmt ? unpack('N', substr($loca, $g * 4, 4)) : 2 * unpack('n', substr($loca, $g * 2, 2));
}
my $glyf = tbl('glyf');

# cmap：文字 → 字形の番号（format 12 があればそれ、なければ format 4）
my $cmap = tbl('cmap');
my $nSub = unpack('n', substr($cmap, 2, 2));
my ($sub12, $sub4);
for my $i (0 .. $nSub - 1) {
	my ($pid, $eid, $off) = unpack('nnN', substr($cmap, 4 + 8 * $i, 8));
	my $fmt = unpack('n', substr($cmap, $off, 2));
	$sub12 = $off if $fmt == 12 and !defined $sub12;
	$sub4 = $off if $fmt == 4 and $pid == 3 and !defined $sub4;
}
my %c2g;
if (defined $sub12) {
	my $n = unpack('N', substr($cmap, $sub12 + 12, 4));
	for my $i (0 .. $n - 1) {
		my ($s, $e, $g) = unpack('NNN', substr($cmap, $sub12 + 16 + 12 * $i, 12));
		for my $c ($s .. $e) { $c2g{$c} = $g + $c - $s if $want{$c}; }
	}
} elsif (defined $sub4) {
	my $segX2 = unpack('n', substr($cmap, $sub4 + 6, 2));
	my $seg = $segX2 / 2;
	my $base = $sub4 + 14;
	for my $i (0 .. $seg - 1) {
		my $end = unpack('n', substr($cmap, $base + 2 * $i, 2));
		my $start = unpack('n', substr($cmap, $base + $segX2 + 2 + 2 * $i, 2));
		my $delta = unpack('n', substr($cmap, $base + 2 * $segX2 + 2 + 2 * $i, 2));
		my $roPos = $base + 3 * $segX2 + 2 + 2 * $i;
		my $ro = unpack('n', substr($cmap, $roPos, 2));
		for my $c ($start .. $end) {
			next unless $want{$c};
			my $g;
			if ($ro == 0) { $g = ($c + $delta) & 0xFFFF; }
			else {
				$g = unpack('n', substr($cmap, $roPos + $ro + 2 * ($c - $start), 2));
				$g = ($g + $delta) & 0xFFFF if $g;
			}
			$c2g{$c} = $g;
		}
	}
}

# 残す字形：.notdef と、文字の字形と、合成字形の部品
my %keep = (0 => 1);
my @stack = values %c2g;
while (@stack) {
	my $g = pop @stack;
	next if $keep{$g}++ and $g != 0;
	my ($a, $b) = ($loc[$g], $loc[$g + 1]);
	next if $b <= $a;
	my $nc = unpack('s>', substr($glyf, $a, 2));
	next if $nc >= 0;
	my $p = $a + 10;
	while (1) {
		my ($flags, $cg) = unpack('nn', substr($glyf, $p, 4));
		push @stack, $cg unless $keep{$cg};
		$p += 4 + (($flags & 1) ? 4 : 2);
		if ($flags & 8) { $p += 2 } elsif ($flags & 0x40) { $p += 4 } elsif ($flags & 0x80) { $p += 8 }
		last unless $flags & 0x20;
	}
}

# glyf と loca を作り直す（loca は4バイト形式）
my $ng = '';
my @nl;
for my $g (0 .. $numGlyphs - 1) {
	push @nl, length $ng;
	next unless $keep{$g};
	my $d = substr($glyf, $loc[$g], $loc[$g + 1] - $loc[$g]);
	$d .= "\0" x ((4 - length($d) % 4) % 4);
	$ng .= $d;
}
push @nl, length $ng;
my $nloca = pack('N*', @nl);
substr($head, 50, 2) = pack('n', 1);
substr($head, 8, 4) = pack('N', 0);

my %out;
for my $t (@order) { $out{$t} = tbl($t); }
# cmap も残した文字だけで作り直す（絞った外の文字は「無い」と答え、ほかのフォントに任せる）
my @cps = sort { $a <=> $b } grep { $c2g{$_} } keys %c2g;
my @grp;
for my $c (@cps) {
	my $g = $c2g{$c};
	if (@grp and $grp[-1][1] == $c - 1 and $grp[-1][2] + ($c - $grp[-1][0]) == $g) { $grp[-1][1] = $c; }
	else { push @grp, [$c, $c, $g]; }
}
my $sub = pack("nnNNN", 12, 0, 16 + 12 * @grp, 0, scalar @grp);
$sub .= pack("NNN", @$_) for @grp;
$out{cmap} = pack("nn", 0, 2) . pack("nnN", 0, 4, 20) . pack("nnN", 3, 10, 20) . $sub;
$out{glyf} = $ng;
$out{loca} = $nloca;
$out{head} = $head;
delete $out{DSIG};
my @tags = sort keys %out;

sub csum {
	my $d = shift;
	$d .= "\0" x ((4 - length($d) % 4) % 4);
	my $s = 0;
	$s = ($s + $_) & 0xFFFFFFFF for unpack('N*', $d);
	return $s;
}
my $n = scalar @tags;
my $es = 1; my $lg = 0;
while ($es * 2 <= $n) { $es *= 2; $lg++; }
my $hdr = pack('Nnnnn', $ver, $n, $es * 16, $lg, $n * 16 - $es * 16);
my $off = 12 + 16 * $n;
my $dir = '';
my $body = '';
for my $t (@tags) {
	my $d = $out{$t};
	$dir .= pack('a4NNN', $t, csum($d), $off + length($body), length($d));
	$body .= $d . ("\0" x ((4 - length($d) % 4) % 4));
}
my $file = $hdr . $dir . $body;
my $adj = (0xB1B0AFBA - csum($file)) & 0xFFFFFFFF;
my $hpos = index($dir, 'head');
my $hoff = unpack('N', substr($dir, $hpos + 8, 4));
substr($file, $hoff + 8, 4) = pack('N', $adj);

open my $oh, '>:raw', $dst or die "$dst: $!";
print $oh $file;
close $oh;
binmode STDOUT, ":encoding(UTF-8)";
printf "字形 %d のうち %d を残した（文字 %d）／ %d → %d バイト\n", $numGlyphs, scalar(keys %keep), scalar(keys %c2g), length($font), length($file);
