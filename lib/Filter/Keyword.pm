package Filter::Keyword;

use Filter::Util::Call;
use Filter::Keyword::Parser;
use Moo;

has parser => (is => 'ro', required => 1);

has parser_object => (is => 'lazy');

sub _build_parser_object {
  my ($self) = @_;
  my %args = %{$self->parser};
  $args{reader} = sub { my $r = filter_read; ($_, $r) };
  $args{re_add} = sub {
    my $parser = shift;
    filter_add(sub {
      my ($string, $code) = $parser->get_next;
      $_ = $string;
      return $code;
    });
  };
  Filter::Keyword::Parser->new(\%args);
}

sub install {
  my ($self) = @_;
  my $parser = $self->parser_object;
  filter_add(sub {
    my ($string, $code) = $parser->get_next;
    $_ = $string;
    return $code;
  });
}

1;
