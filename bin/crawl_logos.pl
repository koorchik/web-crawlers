#!/usr/bin/env perl
use v5.20;
use feature qw/signatures/;
no warnings qw/experimental::signatures/;

use FindBin qw/$Bin/;
use JSON;
use Path::Tiny;
use Mojo::UserAgent;

my $UA = Mojo::UserAgent->new;
my $JSON = JSON->new->utf8->pretty;

main();

sub main {
    my $host = 'http://www.carlogos.org';
    my $results_dir = "$Bin/../results/logos";
    path($results_dir)->mkpath() unless -e $results_dir;

    foreach my $letter ('A'..'Z') {
        my $page_url = "$host/Tags-$letter/";
        my @infos = get_logos_info_from_page($page_url, $host);

        foreach my $logo_info (@infos) {
            download_logo_data($logo_info, $results_dir);
        }
    }
}

sub get_logos_info_from_page($url, $host) {
    say "GET $url";

    my $clean = sub($str) {
       $str =~ tr/a-zA-Z 0-9//cd;
       return $str;
    };

    return $UA->get($url)->res->dom->find('.logobox dt')->map(sub {
        my $link = $_->find('a')->[1];
        my $link_href = $link->attr('href');

        say "GET $link_href";
        my $large_img_src = $UA->get( $link_href )->res->dom
           ->at('.content')->at('img')->attr('src');

        $large_img_src = "$host/$large_img_src" unless $large_img_src =~ /^http/;

        return {
           img_src       => $_->at('img')->attr('src'),
           large_img_src => $large_img_src,
           details_url   => $link_href,
           name          => $clean->( $link->content )
        };
    })->each;
}

sub download_logo_data($logo_info, $results_dir) {
    my $dst_dir = "$results_dir/"  . lc( $logo_info->{name} );
    say "Processing $dst_dir";

    path($dst_dir)->mkpath() unless -e $dst_dir;

    # Save metadata
    path("$dst_dir/meta.json")->spew( $JSON->encode($logo_info) );

    # Download image
    say "  Download $logo_info->{img_src}";
    $UA->get( $logo_info->{img_src} )
       ->res->content->asset
       ->move_to("$dst_dir/image.jpg");

     # Download large image
     say "  Download $logo_info->{large_img_src}";
     $UA->get( $logo_info->{large_img_src} )
        ->res->content->asset
        ->move_to("$dst_dir/image_large.jpg");

     say "---";
}
