package App::BGG::PlayChallenge;
use Moo;
use MooX::Cmd;
 
sub execute {
  my ($self,$args,$chain) = @_;
  printf("%s.execute(\$self,[%s],[%s])\n",
    ref($self),                       # which command is executing?
    join(", ", @$args ),              # what where the arguments?
    join(", ", map { ref } @$chain)   # what's in the command chain?
  );
}

1;
