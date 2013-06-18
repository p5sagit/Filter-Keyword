package Filter::Keyword;
use Moo;

use Filter::Keyword::Filter;
use Filter::Util::Call;
use Scalar::Util qw(weaken);
use Package::Stash::PP;
use B qw(svref_2object);
use B::Hooks::EndOfScope;
use Scalar::Util qw(set_prototype);

sub _compiling_file () {
  my $depth = 0;
  while (my @caller = caller(++$depth)) {
    if ($caller[3] =~ /::BEGIN$/) {
      # older perls report the BEGIN in the wrong file
      return $depth > 1 ? (caller($depth-1))[1] : $caller[1];
      #return $caller[1];
    }
  }
  die;
}

my %filters;
sub install {
  my ($self) = @_;
  $self->shadow_sub;

  my $file = _compiling_file;
  my $filter = $filters{$file} ||= Filter::Keyword::Filter->new;
  $filter->install;

  my $parser = $filter->parser;
  $parser->add_keyword($self);
  $self->keyword_parser($parser);

  on_scope_end {
    $self->remove;
  };
}

has _shadowed_sub => (is => 'rw', clearer => 1);

sub shadow_sub {
  my $self = shift;
  my $stash = $self->stash;
  if (my $shadowed = $stash->get_symbol('&'.$self->keyword_name)) {
    $self->_shadowed_sub($shadowed);
    $stash->remove_symbol('&'.$self->keyword_name);
  }
}

sub remove {
  my ($self) = @_;
  $self->keyword_parser->remove_keyword($self);
  $self->clear_keyword_parser;
  $self->clear_globref;
  my $stash = $self->stash;
  if (my $shadowed = $self->_shadowed_sub) {
    $self->_clear_shadowed_sub;
    $stash->add_symbol('&'.$self->keyword_name, $shadowed);
  }
}

has keyword_parser => (
  is => 'rw',
  weak_ref => 1,
  clearer => 1,
  handles => [
    'match_source',
    'current_match',
  ],
);

has target_package => (is => 'ro', required => 1);
has keyword_name   => (is => 'ro', required => 1);
has parser         => (is => 'ro', required => 1);

sub parse {
  my $self = shift;
  $self->${\$self->parser}(@_);
}

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
  if (my $shadowed = $self->_shadowed_sub) {
    { no warnings 'redefine', 'prototype'; *{$self->globref} = $shadowed; }
  }
  $self->globref_refcount(undef);
};

has globref_refcount => (is => 'rw');

sub save_refcount {
  my ($self) = @_;
  $self->globref_refcount(svref_2object($self->globref)->REFCNT);
}

sub install_matcher {
  my ($self, $post) = @_;
  my $stash = $self->stash;
  my $sub = sub {};
  set_prototype(\&$sub, '*;@') unless $post eq '(';
  { no warnings 'redefine', 'prototype'; *{$self->globref} = $sub; }
  $self->save_refcount;
}

sub have_match {
  my ($self) = @_;
  return 0 unless defined($self->globref_refcount);
  svref_2object($self->globref)->REFCNT > $self->globref_refcount;
}

sub inject_after_scope {
  my $inject = shift;
  on_scope_end {
    filter_add(sub {
      my($status) ;
      $status = filter_read();
      if ($status >= 0) {
        $_ = $inject . $_;
      }
      filter_del();
      $status ;
    });
  };
}

1;
