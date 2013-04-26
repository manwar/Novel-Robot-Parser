#ABSTRACT: TXT的解析模块
package Novel::Robot::Parser::TXT;
use strict;
use warnings;
use utf8;

use File::Find::Rule;
use Encode;
use Encode::Locale;
use Encode::Detect::CJK qw/detect/;
use Moo;
extends 'Novel::Robot::Parser::Base';


has '+site'    => ( default => sub {'TXT'} );
has 'chapter_regex'    => ( 
    is => 'rw', 
    default => sub { 
    #指定分割章节的正则表达式

    #序号
    my $r_num =
qr/[\d０１２３４５６７８９零○〇一二三四五六七八九十百千]+/;
    my $r_split = qr/[上中下]/;
	my $r_not_chap_head = qr/楔子|尾声|内容简介|正文|番外|终章|序言|后记|文案/;

    #第x章，卷x，第x章(大结局)，尾声x
    my $r_head = qr/(卷|第|$r_not_chap_head)?/;
    my $r_tail  = qr/(章|卷|回|部|折)?/;
    my $r_post  = qr/([\s\-\(\/（]+.{0,35})?/;
    my $regex_a = qr/(【?$r_head\s*$r_num\s*$r_tail$r_post】?)/;

    #(1)，(1)xxx
    #xxx(1)，xxx(1)yyy
    #(1-上|中|下)
    my $regex_b_index = qr/[(（]$r_num[）)]/;
    my $regex_b_tail  = qr/$regex_b_index\s*\S+/;
    my $regex_b_head  = qr/\S+\s*$regex_b_index.{0,10}/;
    my $regex_b_split = qr/[(（]$r_num[-－]$r_split[）)]/;
    my $regex_b = qr/$regex_b_head|$regex_b_tail|$regex_b_index|$regex_b_split/;

    #1、xxx，一、xxx
    my $regex_c = qr/$r_num[、.．].{0,10}/;

    #第x卷 xxx 第x章 xxx
    #第x卷/第x章 xxx
    my $regex_d = qr/($regex_a(\s+.{0,10})?){2}/;

	#后记 xxx
	my $regex_e = qr/(【?$r_not_chap_head\s*$r_post】?)/;

	#总体
    my $chap_r = qr/^\s*($regex_a|$regex_b|$regex_c|$regex_d|$regex_e)\s*$/m;

    return $chap_r;
 } );

sub parse_index {
    my ($self, $r) = @_;
    # $r :  writer ,  book ,  path = [ ]

    my %data;
    $data{writer} = $r->{writer};
    $data{book} = $r->{book};

    my $i = 0;

    my $p_ref = ref($r->{path}) eq 'ARRAY' ? $r->{path} : [ $r->{path} ];
    for my $p (@$p_ref){
        my @txts = sort File::Find::Rule->file()->in($p);
        for my $txt (@txts){
            my $txt_data_ref = $self->read_single_txt($txt);
            my $txt_file = decode(locale => $txt);
            for my $t (@$txt_data_ref){
                ++$i;
                $t->{chapter_id} = $i;
                $t->{chapter_url} = $txt_file;

                $data{chapter_info}[$i] = $t;
            }
        }
    }

    $data{chapter_num} = $i;
    $data{index_url} = '';

    return \%data;
}


sub read_single_txt {

    #读入单个TXT文件
    my ($self, $txt) = @_;

    my $charset = $self->detect_file_charset($txt);
    open my $sh, "<:encoding($charset)", $txt;

    my @data;
    my ( $single_toc, $single_content ) = ( '', '' );

    #第一章
    while (<$sh>) {
        next unless /\S/;
        $single_toc = /$self->{chapter_regex}/ ? $1 : $_;
        last;
    } ## end while (<$sh>)

    #后续章节
    while (<$sh>) {
        next unless /\S/;
        if ( my ($new_single_toc) = /$self->{chapter_regex}/ ) {
            if ( $single_toc =~ /\S/ and $single_content =~ /\S/s ) {
                push @data, { chapter => $single_toc, content => $single_content };
                $single_toc = '';
            } ## end if ( $single_toc =~ /\S/...)
            $single_toc .= $new_single_toc . "\n";
            $single_content = '';
        }
        else {
            $single_content .= $_;
        } ## end else [ if ( my ($new_single_toc...))]
    } ## end while (<$sh>)
    push @data, { chapter => $single_toc, content => $single_content };

    #变换TXT->html
    for my $r (@data){
        for ($r->{content}) {
            s#<br\s*/?\s*>#\n#gi;
            s#\s*(.*\S)\s*#<p>$1</p>\n#gm;
            s#<p>\s*</p>##g;
        } ## end for ($chap_c)
    }

    return \@data;
} ## end sub read_single_TXT

sub detect_file_charset {
    my ($self, $file) = @_;
    open my $fh, '<', $file;
    read $fh, my $text, 360;
    return detect($text);
} ## end sub detect_file_charset


no Moo;
1;
