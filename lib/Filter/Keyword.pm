package Filter::Keyword;

# we need the PP implementation's version of remove_symbol
use Package::Stash::PP;
use Filter::Util::Call;
use B qw(svref_2object);
use Moo;

has target_package => (is => 'ro', required => 1);

has stash => (is => 'lazy');

sub _build_stash {
  my ($self) = @_;
  Package::Stash::PP->new($self->target_package);
}

has keyword_name => (is => 'ro', required => 1);

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
  warn "Save: ".$self->globref_refcount(svref_2object($self->globref)->REFCNT);
}

sub refcount_changed {
  my ($self) = @_;
  return 0 unless defined($self->globref_refcount);
  svref_2object($self->globref)->REFCNT > $self->globref_refcount;
}

has info => (is => 'rw', predicate => 'has_info', clearer => 'clear_info');

sub setup {
  my ($self) = @_;
  $self->globref;
  filter_add($self);
}

my $name_re = '[A-Za-z][A-Za-z_0-9]*';

sub filter {
  my ($self) = @_;
  if ($self->has_info) {
    if (delete $self->info->{first}) {
      warn "Attempting short circuit";
      filter_add($self);
      return 0;
    }
    my $info = $self->clear_info;
    $_ = $info->{rest};
    if ($self->refcount_changed) {
      warn "Trapped: ".$info->{name};
      my $name = $info->{name};
      ${$info->{inner}} = sub { warn "Define ${name}" };
      #$self->clear_globref;
      s/{/; sub ${\$info->{name}} { my \$self = shift;/;
    }
warn "Line: $_";
    return 1;
  }
  my $status = filter_read();
warn "Line: $_";
  my $kw = $self->keyword_name;
  if (/(.*?$kw\s+(${name_re}))(.*)\Z/s) {
    my ($start, $name, $rest) = ($1, $2, $3);
    $self->clear_globref if $self->refcount_changed;
    no warnings 'redefine';
    my $inner = sub {};
    *{$self->globref} = sub (*;@) { $inner->(@_) };
    $self->save_refcount;
    $_ = $start;
    $self->info({
      name => $name, rest => $rest, first => 1,
      inner => \$inner
    });
    return 1;
  }
  return $status;
}

1;
