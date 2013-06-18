package Filter::Keyword::Parser;
use Moo;

has reader => (is => 'ro', required => 1);

has re_add => (is => 'ro', required => 1);

has keywords => (is => 'ro', default => sub { [] });

sub add_keyword {
  push @{$_[0]->keywords}, $_[1];
}
sub remove_keyword {
  my ($self, $keyword) = @_;
  my $keywords = $self->keywords;
  for my $idx (0 .. $#$keywords) {
    if ($keywords->[$idx] eq $keyword) {
      splice @$keywords, $idx, 1;
      last;
    }
  }
}

has current_match => (is => 'rw');

has short_circuit => (is => 'rw');

has code => (is => 'rw', default => sub { '' });

has active_keyword => (is => 'rw', clearer => 1);

sub get_next {
  my ($self) = @_;
  if ($self->short_circuit) {
    $self->short_circuit(0);
    $self->${\$self->re_add};
    return ('', 0);
  }
  if (my $keyword = $self->active_keyword) {
    $self->clear_active_keyword;
    $keyword->clear_globref;
    return $keyword->parse($self);
  }
  for my $keyword (@{$self->keywords}) {
    if ($keyword->have_match) {
      $self->active_keyword($keyword);
      $self->short_circuit(1);
      my $match = $self->current_match;
      my $end = $match eq '{' ? '}'
              : $match eq '(' ? ')'
                              : '';
      return ("$end;", 1);
    }
  }
  return $self->check_match;
}

sub fetch_more {
  my ($self) = @_;
  my $code = $self->code||'';
  my ($extra_code, $not_eof) = $self->reader->();
  $code .= $extra_code;
  $self->code($code);
  return $not_eof;
}

sub match_source {
  my ($self, $first, $second) = @_;
  $self->fetch_more while $self->code =~ /\A$first\s+\z/;
  if (my @match = ($self->code =~ /(.*?${first}\s+${second})(.*\n?)\z/)) {
    my $code = pop @match;
    $self->code($code);
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
  for my $keyword (@{ $self->keywords }) {
    if (
      my ($stripped, $matches)
        = $self->match_source(
            $keyword->keyword_name, qr/(\(|[A-Za-z][A-Za-z_0-9]*|{)/
          )
    ) {
      $keyword->install_matcher($matches->[0]);
      $self->current_match($matches->[0]);
      $self->short_circuit(1);
      return ($stripped, 1);
    }
  }
  my $code = $self->code;
  $self->code('');
  return ($code, 1);
}

1;
