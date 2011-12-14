package Filter::Keyword::Parser;

use Package::Stash::PP;
use B qw(svref_2object);
use Scalar::Util qw(set_prototype);
use Moo;

has parser => (is => 'ro', required => 1);

has reader => (is => 'ro', required => 1);

has re_add => (is => 'ro', required => 1);

has target_package => (is => 'ro', required => 1);

has keyword_name => (is => 'ro', required => 1);

has stash => (is => 'lazy');

sub _build_stash {
  my ($self) = @_;
  Package::Stash::PP->new($self->target_package);
}

has globref => (is => 'lazy', clearer => 'clear_globref');

sub _build_globref {
  no strict 'refs'; no warnings 'once';
  \*{join'::',$_[0]->target_package,$_[0]->keyword_name}
}

after clear_globref => sub {
  my ($self) = @_;
  $self->stash->remove_symbol('&'.$self->keyword_name);
  $self->globref_refcount(undef);
};

has globref_refcount => (is => 'rw');

sub save_refcount {
  my ($self) = @_;
  $self->globref_refcount(svref_2object($self->globref)->REFCNT);
}

sub have_match {
  my ($self) = @_;
  return 0 unless defined($self->globref_refcount);
  svref_2object($self->globref)->REFCNT > $self->globref_refcount;
}

has current_match => (is => 'rw');

has short_circuit => (is => 'rw');

has code => (is => 'rw', default => sub { '' });

sub get_next {
  my ($self) = @_;
  if ($self->short_circuit) {
    $self->short_circuit(0);
    $self->${\$self->re_add};
    return ('', 0);
  }
  if ($self->have_match) {
    $self->clear_globref;
    return $self->${\$self->parser};
  }
  return $self->check_match;
}

sub fetch_more {
  my ($self) = @_;
  my $code = $self->code||'';
  my ($extra_code, $not_eof) = $self->${\$self->reader};
  $code .= $extra_code;
  $self->code($code);
  return $not_eof;
}

sub match_source {
  my ($self, $first, $second) = @_;
  $self->fetch_more while $self->code =~ /$first\s+\Z/;
  if (my @match = ($self->code =~ /(.*?${first}\s+${second})(.*)\Z/)) {
    $self->code(pop @match);
    my $found = shift(@match);
    return ($found, \@match);
  }
  return;
}

sub check_match {
  my ($self) = @_;
  unless ($self->code) {
    $self->fetch_more
      or return ('', 0);
  }
  if (
    my ($stripped, $matches)
      = $self->match_source(
          $self->keyword_name, qr/(\(|[A-Za-z][A-Za-z_0-9]*|{)/
        )
  ) {
    my $sub = sub {};
    set_prototype(\&$sub, '*;@') unless $matches->[0] eq '(';
    { no warnings 'redefine'; *{$self->globref} = $sub; }
    $self->save_refcount;
    $self->current_match($matches);
    $self->short_circuit(1);
    return ($stripped, 1);
  }
  my $code = $self->code;
  $self->code('');
  return ($code, 1);
}

1;
