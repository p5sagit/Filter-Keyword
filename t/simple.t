use strictures 1;
use Test::More qw(no_plan);
use Filter::Keyword;

BEGIN {
  (our $Kw = Filter::Keyword->new(
    target_package => __PACKAGE__,
    keyword_name => 'method'
  ))->setup;
}

method main { 'YAY '.$self };

my $x = "method foo bar baz";

method spoon { 'I HAZ A SPOON'};

warn __PACKAGE__->main;
warn __PACKAGE__->spoon;
