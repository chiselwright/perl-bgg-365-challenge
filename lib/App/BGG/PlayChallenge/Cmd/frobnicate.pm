package App::BGG::PlayChallenge::Cmd::frobnicate;
use Moo;
use MooX::Cmd;

sub execute {
    my ($self,$args,$chain) = @_;
    warn __PACKAGE__;
}

1;
