use strictures 1;
use Test::More qw(no_plan);
use Filter::Keyword;

BEGIN {
  (our $Kw = Filter::Keyword->new(
    parser => {
      target_package => __PACKAGE__,
      keyword_name => 'method',
      parser => sub {
        my $obj = shift;
        if (my ($stripped, $matches) = $obj->match_source('', '{')) {
          my $name = $obj->current_match->[0];
          $stripped =~ s/{/; sub ${name} { my \$self = shift;/;
          return ($stripped, 1);
        } else {
          return ('', 1);
        }
      }
    },
  ))->install;
}

method main { 'YAY '.$self };

my $x = "method foo bar baz";

method spoon { 'I HAZ A SPOON'};

warn __PACKAGE__->main;
warn __PACKAGE__->spoon;
