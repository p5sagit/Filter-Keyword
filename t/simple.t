use strictures 1;
use Test::More;
use Filter::Keyword;

my $shadowed_called = 0;
sub shadowed ($&) {
  my ($name, $sub) = @_;
  $shadowed_called++;
  is($name, 'fun', 'shadowed sub called with correct name');
  is($sub->(), 'OH WHAT FUN', 'shadowed sub called with correct sub');
}

BEGIN {
  (our $Kw = Filter::Keyword->new(
    target_package => __PACKAGE__,
    keyword_name => 'method',
    parser => sub {
      my $kw = shift;
      if (my ($stripped, $matches) = $kw->match_source('', '{')) {
        my $name = $kw->current_match;
        $stripped =~ s/{/sub ${name} { my \$self = shift;/;
        return ($stripped, 1);
      }
      else {
        return ('', 1);
      }
    },
  ))->install;
  (our $Kw2 = Filter::Keyword->new(
    target_package => __PACKAGE__,
    keyword_name => 'shadowed',
    parser => sub {
      my $kw = shift;
      if (my ($stripped, $matches) = $kw->match_source('', '{')) {
        my $name = $kw->current_match;
        $stripped =~ s/{/shadowed "${name}", sub { BEGIN { Filter::Keyword::inject_after_scope(';') } /;
        return ($stripped, 1);
      }
      else {
        return ('', 1);
      }
    },
  ))->install;
}

#line 1
method yay { is(__LINE__, 1, 'line number correct inside keyword' ); "YAY $self" } is(__LINE__, 1, 'line number correct on same line after keyword');
is(__LINE__, 2, 'line number correct after first keyword');

#line 1
my $x = __LINE__ . " @{[ __LINE__ ]} method foo @{[ __LINE__ ]} bar baz " . __LINE__;
is(__LINE__, 2, 'line number correct after string with keyword');
is($x, '1 1 method foo 1 bar baz 1', 'line numbers in constructed string are correct');

is(__PACKAGE__->yay, 'YAY ' . __PACKAGE__, 'result of keyword correct');

#line 1
method spoon {
  is(__LINE__, 2, 'line number correct in multiline keyword');
  'I HAZ A SPOON'
}

is(__PACKAGE__->spoon, 'I HAZ A SPOON', 'result of second method correct');

#line 1
shadowed fun { is(__LINE__, 1, 'line number correct inside second keyword'); 'OH WHAT FUN' }

is($shadowed_called, 1, 'shadowed sub called only by filter output');

is(__LINE__, 5, 'line number after shadowed correct');

done_testing;
