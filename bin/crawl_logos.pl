#!/usr/bin/env perl
use v5.20;
use feature qw/signatures/;
no warnings qw/experimental::signatures/;

use FindBin qw/$Bin/;
use JSON qw/encode_json/;
use Path::Tiny;
use Mojo::UserAgent;

my $UA = Mojo::UserAgent->new();

main();

sub main {
    my $host = 'http://www.carlogos.org';
    my $results_dir = "$Bin/../results/logos";
    path($results_dir)->mkpath() unless -e $results_dir;

    foreach my $letter ('A'..'Z') {
        my $page_url = "$host/Tags-$letter/";
        my @infos = get_logos_info_from_page($page_url);

        foreach my $logo_info (@infos) {
            download_logo_data($logo_info, $results_dir);
        }
    }
}

sub get_logos_info_from_page($url) {
    say "GET $url";

    my $clean = sub($str) {
       $str =~ tr/a-zA-Z 0-9//cd;
       return $str;
    };

    return $UA->get($url)->res->dom->find('.logobox dt')->map(sub {{
       img_src => $_->at('img')->attr('src'),
       name    => $clean->( $_->find('a')->[1]->content )
    }})->each;
}

sub download_logo_data($logo_info, $results_dir) {
    my $dst_dir = "$results_dir/"  . lc( $logo_info->{name} );
    say "Processing $dst_dir";

    path($dst_dir)->mkpath() unless -e $dst_dir;

    # Save metadata
    path("$dst_dir/meta.json")->spew( encode_json($logo_info) );

    # Download image
    $UA->get( $logo_info->{img_src} )
       ->res->content->asset
       ->move_to("$dst_dir/image.jpg");
}
