use strictures 1;
use Test::More;
use Filter::Keyword;

sub ::dd {
  use Data::Dumper ();
  local $Data::Dumper::Useqq = 1;
  local $Data::Dumper::Terse = 1;
  my $out = Data::Dumper::Dumper($_[0]);
  chomp $out;
  return $out;
}

BEGIN {
  (our $Kw = Filter::Keyword->new(
    target_package => __PACKAGE__,
    keyword_name => 'method',
    parser => sub {
      my $kw = shift;
      if (my ($stripped, $matches) = $kw->match_source('', '{')) {
        my $name = $kw->current_match->[0];
        $stripped =~ s/{/; sub ${name} { my \$self = shift;/;
        return ($stripped, 1);
      }
      else {
        return ('', 1);
      }
    },
  ))->install;
  (our $Kw2 = Filter::Keyword->new(
    target_package => __PACKAGE__,
    keyword_name => 'function',
    parser => sub {
      my $kw = shift;
      if (my ($stripped, $matches) = $kw->match_source('', '{')) {
        my $name = $kw->current_match->[0];
        $stripped =~ s/{/; sub ${name} {/;
        return ($stripped, 1);
      }
      else {
        return ('', 1);
      }
    },
  ))->install;
}

method yay { is(__LINE__, 38, 'line number correct inside method' ); "YAY $self" } is(__LINE__, 38, 'line number correct on same line after method');

is(__LINE__, 40, 'line number correct after first method');

my $x = "method foo bar baz";

is(__PACKAGE__->yay, 'YAY ' . __PACKAGE__, 'result of method correct');

method spoon {
  is(__LINE__, 47, 'line number correct in multiline method');
  'I HAZ A SPOON'
}

is(__PACKAGE__->spoon, 'I HAZ A SPOON', 'result of second method correct');

function fun { is(__LINE__, 53, 'line number in function correct'); 'OH WHAT FUN' }

is(__PACKAGE__->fun, 'OH WHAT FUN', 'result of function correct');

is(__LINE__, 57, 'line number after function correct');

done_testing;
