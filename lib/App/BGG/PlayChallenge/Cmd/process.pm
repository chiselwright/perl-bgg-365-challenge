package App::BGG::PlayChallenge::Cmd::process;
use Moo;
use MooX::Cmd;
use MooX::Options;

use feature 'say';

use Config::General;
use DateTime;
use LWP::UserAgent;
use XML::LibXML;

option year => (
    is          => 'ro',
    format      => 'i',
    required    => 1,
    short       => 'y',
    default     => sub { DateTime->now->year },
);

option username => (
    is          => 'ro',
    format      => 's',
    required    => 1,
    short       => 'u',
);



has today => (
    is          => 'ro',
    required    => 1,
    lazy        => 1,
    default     => sub { DateTime->now },
);

has current_year => (
    is          => 'ro',
    required    => 1,
    lazy        => 1,
    default     => sub { shift->today->year },
);

has days_in_year => (
    is          =>  'ro',
    lazy        => 1,
    default     => sub { 365 + DateTime->new(year=>shift->year, month=>1, day=>1)->is_leap_year; }
);

has days_in_current_year => (
    is          =>  'ro',
    lazy        => 1,
    default     => sub { 365 + DateTime->new(year=>shift->current_year, month=>1, day=>1)->is_leap_year; }
);


has _config_object => (
    is          => 'ro',
    lazy        => 1,
    builder     => 1,
);

sub _build__config_object {
    my $conf = Config::General->new("challenge.conf");
    my %config = $conf->getall;
    return \%config;
}

sub execute {
    my ($self,$args,$chain) = @_;
    $self->prepare_markup;
}

sub fetch_xml {
    my $self = shift;

    my $page = shift || 1;

    my $api_url = shift || sprintf(
        'https://www.boardgamegeek.com/xmlapi2/plays?username=%s&mindate=%d-01-01&maxdate=%d-12-31&page=%d',
        $self->username,
        $self->year,
        $self->year,
        $page
    );
    #warn "$api_url\n";

    my $ua = LWP::UserAgent->new(agent => "App::BGG::PlayChallenge/0.01");
    my $response = $ua->get($api_url);
    die "couldn't fetch xml\n" unless $response && $response->is_success;
    my $xmlString = $response->content;

    return $xmlString;
}

sub emit_section_title {
    my $title = shift;
    say sprintf("\n[u][b]%s[/b][/u]\n", $title);
}

sub emit_challenge_statuses {
    my $self = shift;

    my $month = shift || 1; # January

    my $ldom = DateTime->last_day_of_month(year => $self->year, month => $month);

    my $api_url = sprintf(
        'https://www.boardgamegeek.com/xmlapi2/plays?username=%s&mindate=%d-%d-01&maxdate=%d-%d-%d&page=%d',
        $self->username,
        $ldom->year,
        $ldom->month,
        $ldom->year,
        $ldom->month,
        $ldom->day,
        1
    );
    my $dom = XML::LibXML->load_xml(string => $self->fetch_xml(1, $api_url));
    #warn $api_url;

    emit_section_title(
        sprintf(
            "%s %d Monthly Challenge",
            $ldom->month_name,
            $ldom->year,
        )
    );

    foreach my $plays_node ($dom->findnodes('/plays')) {
        my $user  = $plays_node->getAttribute('username');
        my $plays = $plays_node->getAttribute('total');
        my @challenges = (
#           {   title           => 'The Still Breathing Test Level',
#               description     => 'Log 1 Plays of Games over the course of this month!!!!',
#               target_plays    => 1,
#           },
            {   title           => 'The Itty Bitty Level',
                description     => 'Log 20 Plays of Games over the course of this month!!!!',
                target_plays    => 20,
            },
            {   title           => 'The "I Think I See Something" Level',
                description     => 'Log 30 Plays of Games over the course of this month!!!!',
                target_plays    => 30,
            },
            {   title           => 'The Grande Level',
                description     => 'Log 40 Plays of Games over the course of this month!!!!',
                target_plays    => 40,
            },
            {   title           => q{The "We're Gonna' Need a Bigger Boat" Level},
                description     => 'Log 50 Plays of Games over the course of this month!!!!',
                target_plays    => 50,
            },
        );
        foreach my $challenge (@challenges) {
            if ($plays >= $challenge->{target_plays}) {
                print ':thumbsup: ';
            }
            else {
                print ':thumbsdown: ';
            }
            printf("%s\n", $challenge->{title});
        }
    }
}


sub emit_plays_logged_section {
    my $self = shift;
    my $plays = shift;

    emit_section_title($self->username);

    # output stars as simple yes/no for days in year
    emit_section_title(
        sprintf('%d Plays Logged in %d', $plays, $self->year)
    );
    for (my $i = 0; $i < $self->days_in_year; $i++) {
        if ($i < $plays) {
            print ':star: ';
        }
        else {
            print ':nostar: ';
        }
    }
    print "\n";
}

sub emit_days_played_section {
    my $self = shift;
    my $tally_ref = shift;
    my %tally_for_date = %{ $tally_ref };
    my $challenge_possible = 1;

    emit_section_title(
        sprintf('%s Days Played in %d', $self->days_in_year, $self->year)
    );

    foreach my $month (1 .. 12) {
        my $ldom = DateTime->last_day_of_month(year => $self->year, month => $month);
        printf("[c]%s: [/c]", $ldom->month_abbr);

        foreach my $day (1 .. $ldom->day) {
            my $dt = $ldom->clone->set_day( $day );
            if (exists $tally_for_date{ $dt->ymd }) {
                print ':star: ';
            }
            else {
                print ':nostar: ';
                $challenge_possible = 0;
            }
        }
        print "\n";
    }

    if (not $challenge_possible) {
        print ":thumbsdown: [i]This challenge can no longer be completed.[/i]\n";
    }
}

sub emit_unique_games_played_section {
    my $self = shift;
    my $tally_ref = shift;
    my %tally_for_game = %{ $tally_ref };
    my $unique_tally = scalar keys %tally_for_game;

    # output stars as simple yes/no for unique games played
    emit_section_title(
        sprintf('%s Unique Games Played in %d', $unique_tally, $self->year)
    );
    for (my $i = 0; $i < $self->days_in_year; $i++) {
        if ($i < $unique_tally) {
            print ':star: ';
        }
        else {
            print ':nostar: ';
        }
    }
    print "\n";
}


sub prepare_markup {
    my $self = shift;

    my $dom = XML::LibXML->load_xml(string => $self->fetch_xml);

    # there should only be one, but let's play it safe
    foreach my $plays_node ($dom->findnodes('/plays')) {
        my $user  = $plays_node->getAttribute('username');
        my $plays = $plays_node->getAttribute('total');

        # we only get 100 results per page, so if there are more than 100 plays we
        # need to loop over the fetch() enough times to grab all the data for the
        # year
        # e.g. int((plays+100) / 100)
        my $num_pages = int(($plays+100) / 100);
        my %tally_for_date=();
        my %tally_for_game=();

        for (my $i=1; $i<=$num_pages; $i++) {
            my $plays_dom = XML::LibXML->load_xml(string => $self->fetch_xml($i));
            # add the plays by date
            foreach my $play_node ($plays_dom->findnodes('/plays/play')) {
                my $date = $play_node->getAttribute('date');
                $tally_for_date{$date}++;
            }
            # add the plays by game (id)
            foreach my $item_node ($plays_dom->findnodes('/plays/play/item')) {
                my $item_id     = $item_node->getAttribute('objectid');
                my $item_name   = $item_node->getAttribute('name');
                $tally_for_game{ $item_id }{name} = $item_name;
                $tally_for_game{ $item_id }{plays}++;
            }
        }

        $self->emit_plays_logged_section($plays);
        $self->emit_days_played_section(\%tally_for_date);
        $self->emit_unique_games_played_section(\%tally_for_game);
        $self->emit_challenge_statuses;

        #my $config = $self->load_config;
        my $config = $self->_config_object;
        my $year = $self->year;
        if (exists $config->{geeklist}{$year} && exists $config->{geeklist}{$year}{$user}) {
            my $current_geeklist = $config->{geeklist}{$year};
            my $current_user     = $config->{geeklist}{$year}{$user};
            say(
                sprintf(
                    "\n\nVisit the item post: https://boardgamegeek.com/geeklist/%d/item/%d#item%d",
                    $current_geeklist->{list_id},
                    $current_user->{item_id},
                    $current_user->{item_id},
                )
            );
        }
    }
}

1;
