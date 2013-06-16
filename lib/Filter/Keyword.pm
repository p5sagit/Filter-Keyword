package Filter::Keyword;
use Moo;

use Filter::Keyword::Filter;
use Scalar::Util qw(weaken);
use Package::Stash::PP;
use B qw(svref_2object);

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
  my $file = _compiling_file;
  $self->shadow_sub;
  my $filter = $filters{$file} ||= Filter::Keyword::Filter->new;
  $filter->install;
  my $parser = $filter->parser;
  $parser->add_keyword($self);
  $self->keyword_parser($parser);
}

sub shadow_sub {
  my $self = shift;
  my $stash = $self->stash;
  if (my $shadowed = $stash->get_symbol('&'.$self->keyword_name)) {
    $stash->remove_symbol('&'.$self->keyword_name);
    $stash->add_symbol('&__'.$self->keyword_name, $shadowed);
  }
}

sub remove {
  my ($self) = @_;
  $self->keyword_parser->remove_keyword($self);
  $self->clear_keyword_parser;
  $self->clear_globref;
}

has keyword_parser => (is => 'rw', weak_ref => 1, clearer => 1);

has target_package => (is => 'ro', required => 1);
has keyword_name   => (is => 'ro', required => 1);
has parser         => (is => 'ro', required => 1);

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

sub DEMOLISH {
  my ($self) = @_;
  $self->remove;
}

1;
