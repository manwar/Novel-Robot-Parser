#ABSTRACT: 起点小说 http://read.qidian.com
package Novel::Robot::Parser::Qidian;
use strict;
use warnings;
use utf8;

use base 'Novel::Robot::Parser';

use Web::Scraper;
#use Encode;

our $BASE_URL = 'http://read.qidian.com';

sub charset {
    'utf8';
}

sub parse_index {

    my ( $self, $html_ref ) = @_;

    my $parse_index = scraper {
        process '//li[@itemprop="chapter"]//a[@itemprop="url"]',
          'chapter_info[]' => {
            'title' => 'TEXT',
            'url'   => '@href'
          };
          process_first '//div[@class="booktitle"]' , 'book' => 'TEXT';
          process_first '//div[@class="booktitle"]//a' , 'writer' => 'TEXT',
          writer_url=>'@href';
    };

    my $ref = $parse_index->scrape($html_ref);

    $ref->{writer}=~s/\*//g;
    $ref->{book}=~s/\s*试玩得起点币.*//sg;

    return $ref;
} ## end sub parse_index

sub parse_chapter {

    my ( $self, $html_ref ) = @_;

    my $parse_chapter = scraper {
        process_first '//div[@id="content"]//script', 'content_url' => '@src', 'content_charset' => '@charset';
        process_first '//span[@itemprop="headline"]', 'title'=> 'TEXT';
        process_first '//span[@itemprop="articleSection"]', 'book' => 'TEXT';
        process_first '//span[@class="info"]//i[2]', 'writer' => 'TEXT';
    };
    my $ref = $parse_chapter->scrape($html_ref);
    $ref->{writer} ||='';
    
    my $c = $self->{browser}->request_url($ref->{content_url});
    $$c=~s#^\s*document.write.*?'\s+##s;
    $$c=~s#'\);\s*$##s;
    $ref->{content} = $$c;

    return $ref;
} ## end sub parse_chapter

1;
