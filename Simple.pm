package LJ::Simple;

use 5.006;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = ();
our @EXPORT = qw();
our $VERSION = '0.03';

## Bring in modules we use
use strict;		# Silly not to be strict
use Socket;		# Required for talking to the LJ server
use POSIX;		# For errno values and other POSIX functions

## Helper function prototypes
sub Debug(@);
sub EncVal($$);
sub SendRequest($$$$);
sub dump_list($$);
sub dump_hash($$);

=pod

=head1 NAME

LJ::Simple - Simple Perl to access LiveJournal

=head1 SYNOPSIS

  use LJ::Simple;

  ## Variables - defaults are shown and normally you'll
  ## not have to set any of the following.

  # Do we show debug info ?
  $LJ::Simple::debug = 0;

  # Do we show the LJ protocol ?
  $LJ::Simple::protocol = 0;

  # Where error messages are placed
  $LJ::Simple::error = "";

  # The timeout on reading from sockets in seconds
  $LJ::Simple::timeout = 10;

  # How much data to read from the socket in one read()
  $LJ::Simple::buffer = 8192;

  ## Object creation
  my $lj = new LJ::Simple ( {
		user	=>	"username",
		pass	=>	"password",
		site	=>	"hostname[:port]",
		proxy	=>	"hostname[:port]",
    } );
  my $lj = LJ::Simple->login ( {
		user	=>	"username",
		pass	=>	"password",
		site	=>	"hostname[:port]",
		proxy	=>	"hostname[:port]",
    } );

  ## Routines which pull information from the login data
  $lj->message()
  $lj->moods($hash_ref)
  $lj->communities()
  $lj->groups($hash_ref)
  $lj->MapGroupToId($group_name)
  $lj->MapIdToGroup($id)
  $lj->pictures($hash_ref)
  $lj->user()
  $lj->fastserver()

  ## Routines for posting journal entries
  # Top level journal access routines
  $lj->UseJournal($event,$journal)
  $lj->NewEntry($event)
  $lj->PostEntry($event)
  $lj->DeleteEntry($item_id)

  # Routines which do more than just set a value within
  # a new journal entry
  $lj->SetSubject($event,$subject)
  $lj->SetDate($event,$time_t)
  $lj->SetMood($event,$mood)

  # Routines for setting subject and journal contents
  $lj->SetEntry($event,@entry)
  $lj->AddToEntry($event,@entry)

  # Routines for setting permissions on the entry
  $lj->SetProtectFriends($event)
  $lj->SetProtectGroups($event,$group1, $group2, ... $groupN)
  $lj->SetProtectPrivate($event)

  # Setting properties for the entry
  $lj->Setprop_backdate($event,$onoff)
  $lj->Setprop_current_mood($event,$mood)
  $lj->Setprop_current_mood_id($event,$id)
  $lj->Setprop_current_music($event,$music)
  $lj->Setprop_preformatted($event,$onoff)
  $lj->Setprop_nocomments($event,$onoff)
  $lj->Setprop_picture_keyword($event,$keyword)
  $lj->Setprop_noemail($event,$onoff)
  $lj->Setprop_unknown8bit($event,$onoff)


=head1 DESCRIPTION

LJ::Simple is a trival API to access LiveJournal. Currently all that it
does is:

=over 2

=item Login

Log into the LiveJournal system

=item Post

Post a new journal entry in the LiveJournal system

=item Delete

Delete an existing post from the LiveJournal system

=back

Variables available are:

=over 4

=item $LJ::Simple::debug

If set to 1, debugging messages are sent to stderr. 

=item $LJ::Simple::protocol

If set to 1 the protocol used to talk to the remote server is sent to stderr.

=item $LJ::Simple::error

Holds error messages, is set with a blank string at the
start of each method. Whilst the messages are relatively free-form,
there are some prefixes which are sometimes used:

  CODE:     An error in the code calling the API
  INTERNAL: An internal error in this module

=item $LJ::Simple::timeout

The time - specified in seconds - to wait for data from the server. If
given a value of C<undef> the API will block until data is avaiable.

=item $LJ::Simple::buffer

The number of bytes to try and read in on each C<sysread()> call.

=back

=cut

## Global variables - documented
# Debug ?
$LJ::Simple::debug=0;
# Show protocol ?
$LJ::Simple::protocol=0;
# Errors
$LJ::Simple::error="";
# Timeout for reading from sockets
$LJ::Simple::timeout = 10;
# How much data to read from the socket in one read()
$LJ::Simple::buffer = 8192;

=pod

The actual methods available are:

=over 4

=cut

## Global variables - internal and undocumented

=pod

=item login

Logs into the LiveJournal system.

  my $lj = new LJ::Simple ( {
		user	=>	"username",
		pass	=>	"password",
		site	=>	"hostname[:port]",
		proxy	=>	"hostname[:port]",
    } );
  my $lj = LJ::Simple->login ( {
		user	=>	"username",
		pass	=>	"password",
		site	=>	"hostname[:port]",
		proxy	=>	"hostname[:port]",
    } );

Where:

  user     is the username to use
  pass     is the password associated with the username
  site     is the remote site to use
  proxy    is the HTTP proxy site to use

Sites defined in C<site> or C<proxy> are a hostname with an
optional port number, separated by a C<:>, i.e.:

  www.livejournal.com
  www.livejournal.com:80

If C<site> is given C<undef> then the code assumes that you wish to
connect to C<www.livejournal.com:80>. If no port is given then port
C<80> is the default.

If C<proxy> is given C<undef> then the code will go directly to the
C<$site>. If no port is given then port C<3128> is the default.

On success this sub-routine returns an C<LJ::Simple> object. On
failure it returns C<undef> with the reason for the failure being
placed in C<$LJ::Simple::error>.

Example code:

  ## Simple example, going direct to www.livejournal.com:80
  my $lj = new LJ::Simple ({ user => "someuser", pass => "somepass" });
  (defined $lj) ||
    die "$0: Failed to access LiveJournal - $LJ::Simple::error\n";

  ## More complex example, going via a proxy server on port 3000 to a
  ## a LiveJournal system available on port 8080 on the machine
  ## www.somesite.com.
  my $lj = new LJ::Simple ({ 
	user	=> "someuser",
	pass	=> "somepass", 
	site	=> "www.somesite.com:8080",
	proxy	=> "proxy.internal:3000",
  });
  (defined $lj) ||
    die "$0: Failed to access LiveJournal - $LJ::Simple::error\n";

=cut
##
## Log into the LiveJournal system. Given that the LJ stuff is just
## layered over HTTP, its not essential to do this. However it does
## mean that we can check the auth details, get some useful info for
## later, etc.
##
sub login($$) {
  # Handle the OOP stuff
  my $this=shift;
  $LJ::Simple::error="";
  if ($#_ != 0) {
    $LJ::Simple::error="CODE: Incorrect usage of login() for argv - see docs";
    return undef;
  }
  # Get the hash
  my $hr = shift;
  my $class = ref($this) || $this;
  my $self = {};
  bless $self,$class;
  if ((!exists $hr->{user})||($hr->{user} eq "") ||
      (!exists $hr->{pass})||($hr->{pass} eq "")) {
    $LJ::Simple::error="CODE: Incorrect usage of login() - see docs";
    return undef;
  }
  $self->{auth}={
	user	=>	$hr->{user},
	pass	=>	$hr->{pass},
  };
  eval { require Digest::MD5 };
  if (!$@) {
    Debug("Using Digest::MD5");
    my $md5=Digest::MD5->new;
    $md5->add($hr->{pass});
    $self->{auth}->{hash}=$md5->hexdigest;
    delete $self->{auth}->{pass};
  }
  if ((exists $hr->{site})&&(defined $hr->{site})&&($hr->{site} ne "")) {
    my $site_port=80;
    if ($hr->{site}=~/\s*(.*?):([0-9]+)\s*$/) {
      $hr->{site} = $1;
      $site_port = $2;
    }
    $self->{lj}={
  	host	=>	$hr->{site},
  	port	=>	$site_port,
    }
  } else {
    $self->{lj}={
  	host	=>	"www.livejournal.com",
  	port	=>	80,
    }
  }
  if ((exists $hr->{proxy})&&(defined $hr->{proxy})&&($hr->{proxy} ne "")) {
    my $proxy_port=3128;
    if ($hr->{proxy}=~/\s*(.*?):([0-9]+)\s*$/) {
      $hr->{proxy} = $1;
      $proxy_port = $2;
    }
    $self->{proxy}={
  	host	=>	$hr->{proxy},
  	port	=>	$proxy_port,
    }
  } else {
    $self->{proxy}=undef;
  }
  # Set fastserver to 0 until we know better
  $self->{fastserver}=0;

  # Perform the actual login
  $self->SendRequest("login", {
	"moods"		=>	1,
	"getpickws"	=>	1,
    },undef) || return undef;

  # Now see if we can set fastserver
  if ( (exists $self->{request}->{lj}->{fastserver}) &&
       ($self->{request}->{lj}->{fastserver} == 1) ) {
    $self->{fastserver}=1;
  }

  # Moods
  $self->{moods}=undef;
  $self->{mood_map}=undef;
  # Shared access journals
  $self->{access}=undef;
  # User groups
  $self->{groups}=undef;
  # Images defined
  $self->{pictures}=undef;
  # Message from LJ
  $self->{message}=undef;

  # Handle moods, etc.
  my ($k,$v)=(undef,undef);
  while(($k,$v) = each %{$self->{request}->{lj}}) {

    # Message from LJ
    if ($k eq "message") {
      $self->{message}=$v;

    # Moods
    } elsif ($k=~/^mood_([0-9]+)_([a-z]+)/o) {
      my ($id,$type)=($1,$2);
      if (!defined $self->{moods}) {
        $self->{moods}={};
      }
      if (!exists $self->{moods}->{$id}) {
        $self->{moods}->{$id}={};
      }
      if ($type eq "id") {
        $self->{moods}->{$id}->{id}=$v;
      } elsif ($type eq "name") {
        $self->{moods}->{$id}->{name}=$v
      }

    # Picture key words
    } elsif ($k=~/^(pickw[^_]*)_([0-9]+)/o) {
      my ($type,$id)=($1,$2);
      if (!defined $self->{pictures}) {
        $self->{pictures}={};
      }
      if (!exists $self->{pictures}->{$id}) {
        $self->{pictures}->{$id}={};
      }
      if ($type eq "pickwurl") {
        $self->{pictures}->{$id}->{url}=$v;
      } elsif ($type eq "pickw") {
        $self->{pictures}->{$id}->{name}=$v
      }

    # Shared access journals
    } elsif ($k=~/^access_([0-9]+)/) {
      if (!defined $self->{access}) {
        $self->{access}={};
      }
      $self->{access}->{$v}=1;

    # Groups
    } elsif ($k=~/^frgrp_([0-9]+)_(.*)/) {
      my ($id,$type)=($1,$2);
      if (!defined $self->{groups}) {
        $self->{groups}={
          src  => {},  # Source data
          id   => {},  # Id -> name mapping
          name => {},  # Real data, name keyed
        };
      }
      if (!exists $self->{groups}->{src}->{$id}) {
        $self->{groups}->{src}->{$id}={};
      }
      if ($type eq "sortorder") {
        $self->{groups}->{src}->{$id}->{sort}=$v;
      } elsif ($type eq "name") {
        $self->{groups}->{src}->{$id}->{name}=$v
      }
    }
  }

  ## We now handle the group hash fully. Note in the case
  ## of groups having the same name, only the first will
  ## go into the name hash.
  ($k,$v)=(undef,undef);
  while(($k,$v)=each %{$self->{groups}->{src}}) {
    $self->{groups}->{id}->{$k}=$v->{name};
    if (!exists $self->{groups}->{name}->{$v->{name}}) {
      $self->{groups}->{name}->{$v->{name}} = {
        id   => $k,
        name => $v->{name},
        sort => $v->{sort},
      };
    }
  }

  ##
  ## And now we handle the mood map fully
  ##
  $self->{mood_map}={};
  foreach (values %{$self->{moods}}) {
    $self->{mood_map}->{lc($_->{name})}=$_->{id};
  }

  Debug(dump_hash($self,""));
  
  ## Logged in, so return self.
  return $self;
}

## Define reference from new to login
*new="";
*new=\&login;


=pod

=item $lj->message()

Returns back a message set in the LiveJournal system. Either
returns back the message or C<undef> if no message is set.

Example code:

  my $msg = $lj->message();
  (defined $msg) &&
    print "LJ Message: $msg\n";

=cut
sub message($) {
  my $self=shift;
  return $self->{message};
}

=pod

=item $lj->moods($hash_ref)

Takes a reference to a hash and fills it with information about
the moods returned back by the server. Either returns back the
same hash reference or C<undef> on error.

The hash the given reference is pointed to is emptied before
it is used and after a successful call the hash given will
contain:

  %hash = (
    list    => [ list of mood names, alphabetical ]
    moods   => {
      mood_name => mood_id
    }
    idents  => {
      mood_id   => mood_name
    }
  )


Example code:

  my %Moods=();
  if (!defined $lj->moods(\%Moods)) {
    die "$0: LJ error - $LJ::Simple::error";
  }
  foreach (@{$Moods{list}}) {
    print "$_ -> $Moods{moods}->{$_}\n";
  }
  

=cut
sub moods($$) {
  my $self=shift;
  my ($hr) = @_;
  $LJ::Simple::error="";
  if (ref($hr) ne "HASH") {
    $LJ::Simple::error="CODE: moods() not given a hash reference";
    return undef;
  }
  if (!defined $self->{moods}) {
    $LJ::Simple::error="Unable to return moods - not requested at login";
    return undef;
  }
  %{$hr}=(
    list	=> [],
    moods	=> {},
    idents	=> {},
  );
  my ($k,$v);
  while(($k,$v)=each %{$self->{moods}}) {
    push(@{$hr->{list}},$v->{name});
    $hr->{moods}->{$v->{name}}=$v->{id};
    $hr->{idents}->{$v->{id}}=$v->{name};
  }
  $hr->{list} = [ (sort { $a cmp $b } @{$hr->{list}}) ];
  return $hr;
}

=pod

=item $lj->communities()

Returns a list of shared access communities the user logged in can
post to. Returns an empty list if no communities are available

Example code:

  my @communities = $lj->communities();
  print join("\n",@communities),"\n";

=cut
sub communities($) {
  my $self=shift;
  $LJ::Simple::error="";
  (defined $self->{access}) || return ();
  return sort {$a cmp $b} (keys %{$self->{access}});
}


=pod

=item $lj->groups($hash_ref)

Takes a reference to a hash and fills it with information about
the friends groups the user has configured for themselves. Either
returns back the hash reference or C<undef> on error.

The hash the given reference points to is emptied before it is
used and after a successful call the hash given will contain
the following:

   %hash = (
     "name" => {
       "Group name" => {
         id   => "Number of the group",
         sort => "Sort order",
         name => "Group name (copy of key)",
       },
     },
     "id"   => {
       "Id"   => "Group name",
     },
   );

Example code:

  my %Groups=();
  if (!defined $lj->groups(\%Groups)) {
    die "$0: LJ error - $LJ::Simple::error";
  }
  my ($id,$name)=(undef,undef);
  while(($id,$name)=each %{$Groups{id}}) {
    my $srt=$Groups{name}->{$name}->{sort};
    print "$id\t=> $name [$srt]\n";
  }

=cut
sub groups($) {
  my $self=shift;
  my ($hr) = @_;
  $LJ::Simple::error="";
  if (ref($hr) ne "HASH") {
    $LJ::Simple::error="CODE: groups() not given a hash reference";
    return undef;
  }
  if (!defined $self->{groups}) {
    $LJ::Simple::error="Unable to return groups - none defined";
    return undef;
  }
  %{$hr}=(
    name => {},
    id   => {},
  );
  my ($k,$v);
  while(($k,$v)=each %{$self->{groups}->{id}}) {
    $hr->{id}->{$k}=$v;
  }
  while(($k,$v)=each %{$self->{groups}->{name}}) {
    $hr->{name}->{$k}={};
    my ($lk,$lv);
    while(($lk,$lv)=each %{$self->{groups}->{name}->{$k}}) {
       $hr->{name}->{$k}->{$lk}=$lv;
    }
  }
  return $hr;
}


=pod

=item $lj->MapGroupToId($group_name)

Used to map a given group name to its identity. On
success returns the identity for the group name. On
failure it returns C<undef> and sets
C<$LJ::Simple::error>.

=cut
sub MapGroupToId($$) {
  my $self=shift;
  my ($grp)=@_;
  $LJ::Simple::error="";
  if (!defined $self->{groups}) {
    $LJ::Simple::error="Unable to map group to id - none defined";
    return undef;
  }
  if (!exists $self->{groups}->{name}->{$grp}) {
    $LJ::Simple::error="No such group";
    return undef;
  }
  return $self->{groups}->{name}->{$grp}->{id};
}


=pod

=item $lj->MapIdToGroup($id)

Used to map a given identity to its group name. On
success returns the group name for the identity. On
failure it returns C<undef> and sets
C<$LJ::Simple::error>.

=cut
sub MapIdToGroup($$) {
  my $self=shift;
  my ($id)=@_;
  $LJ::Simple::error="";
  if (!defined $self->{groups}) {
    $LJ::Simple::error="Unable to map group to id - none defined";
    return undef;
  }
  if (!exists $self->{groups}->{id}->{$id}) {
    $LJ::Simple::error="No such group ident";
    return undef;
  }
  return $self->{groups}->{id}->{$id};
}

=pod


=item $lj->pictures($hash_ref)

Takes a reference to a hash and fills it with information about
the pictures the user has configured for themselves. Either
returns back the hash reference or C<undef> on error. Note that
the user has to have defined picture keywords for this to work.

The hash the given reference points to is emptied before it is
used and after a successful call the hash given will contain
the following:

   %hash = (
     "keywords"	=> "URL of picture",
   );

Example code:

  my %pictures=();
  if (!defined $lj->pictures(\%pictures)) {
    die "$0: LJ error - $LJ::Simple::error";
  }
  my ($keywords,$url)=(undef,undef);
  while(($keywords,$url)=each %pictures) {
    print "\"$keywords\"\t=> $url\n";
  }


=cut
sub pictures($$) {
  my $self=shift;
  my ($hr)=@_;
  $LJ::Simple::error="";
  if (!defined $self->{pictures}) {
    $LJ::Simple::error="Unable to return pictures - none defined";
    return undef;
  }
  if (ref($hr) ne "HASH") {
    $LJ::Simple::error="CODE: pictures() not given a hash reference";
    return undef;
  }
  %{$hr}=();
  foreach (values %{$self->{pictures}}) {
    $hr->{$_->{name}}=$_->{url};
  }
  return $hr;
}


=pod

=item $lj->user()

Returns the username used to log into LiveJournal

Example code:
 
  my $user = $lj->user();

=cut
sub user($) {
  my $self=shift;
  $LJ::Simple::error="";
  return $self->{auth}->{user};
}


=pod

=item $lj->fastserver()

Used to tell if the user which was logged into the LiveJournal system can use the
fast servers or not. Returns C<1> if the user can use the fast servers, C<0>
otherwise.

Example code:

  if ($lj->fastserver()) {
    print STDERR "Using fast server for ",$lj->user(),"\n";
  }

=cut
sub fastserver($) {
  my $self=shift;
  $LJ::Simple::error="";
  return $self->{fastserver};
}


=pod

=item $lj->NewEntry($event)

Prepares for a new journal entry to be sent into the LiveJournal system.
Takes a reference to a hash which will be emptied and prepared for use
by the other routines used to prepare a journal entry for posting.

On success returns C<1>, on failure returns C<0>

Example code:

  my %Entry=();
  $lj->NewEntry(\%Entry) 
    || die "$0: Failed to prepare new post - $LJ::Simple::error\n";

=cut
sub NewEntry($$) {
  my $self=shift;
  my ($event)=@_;
  $LJ::Simple::error="";
  if (ref($event) ne "HASH") {
    $LJ::Simple::error="CODE: Not given a hash reference";
    return 0;
  }
  ## Build the event hash - put defaults in
  my $ltime=time();
  my @ltime=localtime($ltime);
  %{$event}=(
	__new_entry	=>	1,
	event		=>	undef,
	lineenddings	=>	"unix",
	subject		=>	undef,
	year		=>	$ltime[5]+1900,
	mon		=>	$ltime[4]+1,
	day		=>	$ltime[3],
	hour		=>	$ltime[2],
	min		=>	$ltime[1],
	__timet		=>	$ltime,
  );
  return 1;
}


=pod 

=item $lj->SetDate($event,$time_t)

Sets the date for the event being built from the given C<time_t> (i.e. seconds
since epoch) value. Bare in mind that you may need to call
C<$lj->Setprop_backdate(\%Event,1)> to backdate the journal entry if the journal being
posted to has events more recent than the date being set here. Returns C<1> on
success, C<0> on failure.

If the value given for C<time_t> is C<undef> then the current time is used.
If the value given for C<time_t> is negative then it is taken to be relative
to the current time, i.e. a value of C<-3600> is an hour earlier than the
current time.

Note that C<localtime()> is called to convert the C<time_t> value into
the year, month, day, hours and minute values required by LiveJournal.
Thus the time given to LiveJournal will be the local time as shown on
the machine the code is running on.

Example code:

  ## Set date to current time
  $lj->SetDate(\%Event,undef)
    || die "$0: Failed to set date of entry - $LJ::Simple::error\n";

  ## Set date to Wed Aug 14 11:56:42 2002 GMT
  $lj->SetDate(\%Event,1029326202)
    || die "$0: Failed to set date of entry - $LJ::Simple::error\n";

  ## Set date to an hour ago
  $lj->SetDate(\%Event,-3600)
    || die "$0: Failed to set date of entry - $LJ::Simple::error\n";

=cut
sub SetDate($$$) {
  my $self=shift;
  my ($event,$timet)=@_;
  $LJ::Simple::error="";
  if (ref($event) ne "HASH") {
    $LJ::Simple::error="CODE: Not given a hash reference";
    return 0;
  }
  (defined $timet) || ($timet=time());
  if ($timet<0) {
    $timet=time() + $timet;
  }
  my @ltime=localtime($timet);
  $event->{__timet}=$timet;
  $event->{year}=$ltime[5]+1900;
  $event->{mon}=$ltime[4]+1;
  $event->{day}=$ltime[3];
  $event->{hour}=$ltime[2];
  $event->{min}=$ltime[1];
  return 1;
}


=pod

=item $lj->SetMood($event,$mood)

Given a mood this routine sets the mood for the journal entry. Unlike the
more direct C<$lj->Setprop_current_mood()> and C<$lj->Setprop_current_mood_id(\%Event,)>
routines, this routine will attempt to first attempt to find the mood given
to it in the mood list returned by the LiveJournal server. If it is unable to
find a suitable mood then it uses the text given.

Returns C<1> on success, C<0> otherwise.

Example code:

  $lj->SetMood(\%Event,"happy")
    || die "$0: Failed to set mood - $LJ::Simple::error\n";

=cut
sub SetMood($$$) {
  my $self=shift;
  my ($event,$mood) = @_;
  $LJ::Simple::error="";
  if (ref($event) ne "HASH") {
    $LJ::Simple::error="CODE: Not given a hash reference";
    return 0;
  }
  ## Simple opt - none of the mood names have a space in them
  if ($mood!~/\s/) { 
    my $lc_mood=lc($mood);
    if (exists $self->{mood_map}->{$lc_mood}) {
      return $self->Setprop_current_mood_id($event,$self->{mood_map}->{$lc_mood})
    }
  }
  return $self->Setprop_current_mood($mood);
}



=pod

=item $lj->UseJournal($event,$journal)

The journal entry will be posted into the shared journal given
as an argument rather than the default journal for the user.

Returns C<1> on success, C<0> otherwise.

Example code:

  $lj->UseJournal(\%Event,"some_community")
    || die "$0: Failed to - $LJ::Simple::error\n";

=cut
sub UseJournal($$$) {
  my $self=shift;
  my ($event,$journal) = @_;
  $LJ::Simple::error="";
  if (ref($event) ne "HASH") {
    $LJ::Simple::error="CODE: Not given a hash reference";
    return 0;
  }
  if (!exists $self->{access}->{$journal}) {
    $LJ::Simple::error="user unable to post to journal \"$journal\"";
    return 0;
  }
  $event->{usejournal}=$journal;
  return 1;
}


=pod

=item $lj->SetSubject($event,$subject)

Sets the subject for the journal entry. The subject has the following
limitations:

 o Limited to a length of 255 characters
 o No newlines are allowed

Returns C<1> on success, C<0> otherwise.

Example code:

  $lj->SetSubject(\%Event,"Some subject")
    || die "$0: Failed to set subject - $LJ::Simple::error\n";

=cut
sub SetSubject($$$) {
  my $self=shift;
  my ($event,$subject) = @_;
  $LJ::Simple::error="";
  if (ref($event) ne "HASH") {
    $LJ::Simple::error="CODE: Not given a hash reference";
    return 0;
  }
  if (length($subject)>255) {
    my $len=length($subject);
    $LJ::Simple::error="Subject length limited to 255 characters [given $len]";
    return 0;
  }
  if ($subject=~/[\r\n]/) {
    $LJ::Simple::error="New lines not allowed in subject";
    return 0;
  }
  $event->{subject}=$subject;
  return 1;
}


=pod

=item $lj->SetEntry($event,@entry)

Sets the entry for the journal; takes a list of strings. It should be noted
that this list will be C<join()>ed together with a newline between each
list entry.

If the list is null or C<undef> then any existing entry is removed.

Returns C<1> on success, C<0> otherwise.

Example code:

  # Single line entry
  $lj->SetEntry(\%Event,"Just a simple entry")
    || die "$0: Failed to set entry - $LJ::Simple::error\n";
  
  # Three lines of text
  my @stuff=(
       "Line 1",
       "Line 2",
       "Line 3",
  );
  $lj->SetEntry(\%Event,@stuff)
    || die "$0: Failed to set entry - $LJ::Simple::error\n";

  # Clear the entry
  $lj->SetEntry(\%Event,undef)
    || die "$0: Failed to set entry - $LJ::Simple::error\n";
  $lj->SetEntry(\%Event)
    || die "$0: Failed to set entry - $LJ::Simple::error\n";

=cut
sub SetEntry($$@) {
  my $self=shift;
  my ($event,@entry) = @_;
  $LJ::Simple::error="";
  if (ref($event) ne "HASH") {
    $LJ::Simple::error="CODE: Not given a hash reference";
    return 0;
  }
  if ((!defined $entry[0]) || ($#entry == -1)) {
    $event->{event}=undef;
  } else {
    $event->{event}=join("\n",@entry);
  }
  return 1;
}


=pod

=item $lj->AddToEntry($event,@entry)

Adds a string to the existing journal entry being worked on. The new data
will be appended to the existing entry with a newline separating them.
It should be noted that as with C<$lj->SetEntry()> the list given to
this routine will be C<join()>ed together with a newline between each 
list entry.

If C<$lj->SetEntry()> has not been called then C<$lj->AddToEntry()> acts
in the same way as C<$lj->SetEntry()>.

If C<$lj->SetEntry()> has already been called then calling C<$lj->AddToEntry()>
with a null list or a list which starts with C<undef> is a NOP.

Returns C<1> on success, C<0> otherwise.

Example code:

  # Single line entry
  $lj->AddToEntry(\%Event,"Some more text")
    || die "$0: Failed to set entry - $LJ::Simple::error\n";
  
  # Three lines of text
  my @stuff=(
       "Line 5",
       "Line 6",
       "Line 7",
  );
  $lj->AddToEntry(\%Event,@stuff)
    || die "$0: Failed to set entry - $LJ::Simple::error\n";

=cut
sub AddToEntry($$@) {
  my $self=shift;
  my ($event,@entry) = @_;
  $LJ::Simple::error="";
  if (ref($event) ne "HASH") {
    $LJ::Simple::error="CODE: Not given a hash reference";
    return 0;
  }
  if (!defined $event->{event}) {
    if ((!defined $entry[0]) || ($#entry == -1)) {
      $event->{event}=undef;
    } else {
      $event->{event}=join("\n",@entry);
    }
  } else {
    if ((!defined $entry[0]) || ($#entry == -1)) {
      return 1;
    }
    $event->{event}=join("\n",$event->{event},@entry);
  }
  return 1;
}



=pod

=item $lj->SetProtectFriends($event)

Sets the current post so that only friends can read the journal entry. Returns
C<1> on success, C<0> otherwise.

Example code:

  $lj->SetProtectFriends(\%Event)
    || die "$0: Failed to protect via friends - $LJ::Simple::error\n";

=cut
sub SetProtectFriends($$) {
  my $self=shift;
  my ($event)=@_;
  $LJ::Simple::error="";
  if (ref($event) ne "HASH") {
    $LJ::Simple::error="CODE: Not given a hash reference";
    return 0;
  }
  $event->{security}="usemask";
  $event->{allowmask}=1;
  return 1;
}


=pod

=item $lj->SetProtectGroups($event,$group1, $group2, ... $groupN)

Takes a list of group names and sets the current entry so that only those
groups can read the journal entry. Returns
C<1> on success, C<0> otherwise.

Example code:

  $lj->SetProtectGroups(\%Event,"foo","bar")
    || die "$0: Failed to protect via group - $LJ::Simple::error\n";

=cut
sub SetProtectGroups($$@) {
  my $self=shift;
  my ($event,@grps) = @_;
  $LJ::Simple::error="";
  if (ref($event) ne "HASH") {
    $LJ::Simple::error="CODE: Not given a hash reference";
    return 0;
  }
  if ($#grps==-1) {
    $LJ::Simple::error="No group names given";
    return 0;
  }
  $event->{security}="usemask";
  my $g;
  my $mask=0;
  foreach $g (@grps) {
    if (!exists $self->{groups}->{name}->{$g}) {
      $LJ::Simple::error="Group \"$g\" does not exist";
      return 0;
    }
    $mask=$mask | (1 << $self->{groups}->{name}->{$g}->{id});
  }
  $event->{allowmask}=$mask;
  return 1;
}

=pod

=item $lj->SetProtectPrivate($event)

Sets the current post so that the owner of the journal only can read the
journal entry. Returns C<1> on success, C<0> otherwise.

Example code:

  $lj->SetProtectPrivate(\%Event)
    || die "$0: Failed to protect via private - $LJ::Simple::error\n";

=cut
sub SetProtectPrivate($$) {
  my $self=shift;
  my ($event) = @_;
  $LJ::Simple::error="";
  if (ref($event) ne "HASH") {
    $LJ::Simple::error="CODE: Not given a hash reference";
    return 0;
  }
  $event->{security}="private";
  (exists $event->{allowmask}) &&
    delete $event->{allowmask};
  return 1;
}


##
## Helper function used to set meta data
##
sub Setprop_general($$$$$$) {
  my ($self,$event,$prop,$caller,$type,$data)=@_;
  $LJ::Simple::error="";
  if (ref($event) ne "HASH") {
    $LJ::Simple::error="CODE: Not given a hash reference";
    return 0;
  }
  my $nd=undef;
  if ($type eq "bool") {
    if (($data == 1)||($data == 0)) {
      $nd=$data;
    } else {
      $LJ::Simple::error="INTERNAL: Invalid value [$data] for type bool [from $caller]";
      return 0;
    }
  } elsif ($type eq "char") {
    $nd=$data;
  } elsif ($type eq "num") {
    if ($data!~/^[0-9]+$/o) {
      $LJ::Simple::error="INTERNAL: Invalid value [$data] for type num [from $caller]";
      return 0;
    }
    $nd=$data;
  } else {
    $LJ::Simple::error="INTERNAL: Unknown type \"$type\" [from $caller]";
    return 0;
  }
  if (!defined $nd) {
    $LJ::Simple::error="INTERNAL: Setprop_general did not set \$nd [from $caller]";
    return 0;
  }
  $event->{"prop_$prop"}=$nd;
  return 1;
}

=pod

=item $lj->Setprop_backdate($event,$onoff)

Used to indicate if the journal entry being written should be back dated or not. Back dated
entries do not appear on the friends view of your journal entries. The C<$onoff>
value takes either C<1> for switching the property on or C<0> for switching the
property off. Returns C<1> on success, C<0> on failure.

You will need to set this value if the journal entry you are sending has a
date earlier than other entries in your journal.

Example code:

  $lj->Setprop_backdate(\%Event,1) ||
    die "$0: Failed to set back date property - $LJ::Simple::error\n";

=cut
sub Setprop_backdate($$$) {
  my ($self,$event,$onoff)=@_;
  $LJ::Simple::error="";
  return $self->Setprop_general($event,"opt_backdate","Setprop_backdate","bool",$onoff);
}


=pod

=item $lj->Setprop_current_mood($event,$mood)

Used to set the current mood for the journal being written. This takes a string which
describes the mood.

It is better to use C<$lj->SetMood()> as that will automatically use a
mood known to the LiveJournal server if it can.

Returns C<1> on success, C<0> on failure.

Example code:

  $lj->Setprop_current_mood(\%Event,"Happy, but tired") ||
    die "$0: Failed to set current_mood property - $LJ::Simple::error\n";

=cut
sub Setprop_current_mood($$$) {
  my ($self,$event,$mood)=@_;
  $LJ::Simple::error="";
  if ($mood=~/[\r\n]/) {
    $LJ::Simple::error="Mood may not contain a new line";
    return 0;
  }
  return $self->Setprop_general($event,"current_mood","Setprop_current_mood","char",$mood);
}

=pod

=item $lj->Setprop_current_mood_id($event,$id)

Used to set the current mood_id for the journal being written. This takes a number which
refers to a mood_id the LiveJournal server knows about. Note that the number
given here is only validated if the mood list was requested for when the
LiveJournal login occured.

It is better to use C<$lj->SetMood()> as that will automatically use a
mood known to the LiveJournal server if it can.

Returns C<1> on success, C<0> on failure.

Example code:

  $lj->Setprop_current_mood_id(\%Event,15) ||
    die "$0: Failed to set current_mood_id property - $LJ::Simple::error\n";

=cut
sub Setprop_current_mood_id($$$) {
  my ($self,$event,$data)=@_;
  $LJ::Simple::error="";
  if (defined $self->{moods}) {
    if (!exists $self->{moods}->{$data}) {
      $LJ::Simple::error="The mood_id $data is not known by the LiveJournal server";
      return 0;
    }
  }
  return $self->Setprop_general($event,"current_moodid","Setprop_current_mood_id","num",$data);
}


=pod

=item $lj->Setprop_current_music($event,$music)

Used to set the current music for the journal entry being written. This takes
a string.

Returns C<1> on success, C<0> on failure.

Example code:

  $lj->Setprop_current_music(\%Event,"Collected euphoric dance") ||
    die "$0: Failed to set current_music property - $LJ::Simple::error\n";

=cut
sub Setprop_current_music($$$) {
  my ($self,$event,$data)=@_;
  $LJ::Simple::error="";
  return $self->Setprop_general($event,"current_music","Setprop_current_music","char",$data);
}

=pod

=item $lj->Setprop_preformatted($event,$onoff)

Used to set if the text for the journal entry being written is preformatted in HTML
or not. This takes a boolean value of C<1> for true and C<0> for false.

Returns C<1> on success, C<0> on failure.

Example code:

  $lj->Setprop_preformatted(\%Event,1) ||
    die "$0: Failed to set property - $LJ::Simple::error\n";

=cut
sub Setprop_preformatted($$$) {
  my ($self,$event,$data)=@_;
  $LJ::Simple::error="";
  return $self->Setprop_general($event,"opt_preformatted","Setprop_preformatted","bool",$data);
}


=pod

=item $lj->Setprop_nocomments($event,$onoff)

Used to set if the journal entry being written can be commented on or not. This takes
a boolean value of C<1> for true and C<0> for false.

Returns C<1> on success, C<0> on failure.

Example code:

  $lj->Setprop_nocomments(\%Event,1) ||
    die "$0: Failed to set property - $LJ::Simple::error\n";

=cut
sub Setprop_nocomments($$$) {
  my ($self,$event,$data)=@_;
  $LJ::Simple::error="";
  return $self->Setprop_general($event,"opt_nocomments","Setprop_nocomments","bool",$data);
}


=pod

=item $lj->Setprop_picture_keyword($event,$keyword)

Used to set the picture keyword for the journal entry being written. This takes
a string. We check to make sure that the picture keyword exists.

Returns C<1> on success, C<0> on failure.

Example code:

  $lj->Setprop_picture_keyword(\%Event,"Some photo") ||
    die "$0: Failed to set property - $LJ::Simple::error\n";

=cut
sub Setprop_picture_keyword($$$) {
  my ($self,$event,$data)=@_;
  $LJ::Simple::error="";
  my $match=0;
  foreach (values %{$self->{pictures}}) {
    if ($_->{name} eq $data) {
      $match=1;
      last;
    }
  }
  if (!$match) {
    $LJ::Simple::error="Picture keyword not associated with journal";
    return 0;
  }
  return $self->Setprop_general($event,"picture_keyword","Setprop_picture_keyword","char",$data);
}


=pod

=item $lj->Setprop_noemail($event,$onoff)

Used to say that comments on the journal entry being written should not be emailed.
This takes boolean value of C<1> for true and C<0> for false.

Returns C<1> on success, C<0> on failure.

Example code:

  $lj->Setprop_noemail(\%Event,1) ||
    die "$0: Failed to set property - $LJ::Simple::error\n";

=cut
sub Setprop_noemail($$$) {
  my ($self,$event,$data)=@_;
  $LJ::Simple::error="";
  return $self->Setprop_general($event,"opt_noemail","Setprop_noemail","bool",$data);
}


=pod

=item $lj->Setprop_unknown8bit($event,$onoff)

Used say that there is 8-bit data which is not in UTF-8 in the journal entry
being written. This takes a boolean value of C<1> for true and C<0> for false.

Returns C<1> on success, C<0> on failure.

Example code:

  $lj->Setprop_unknown8bit(\%Event,1) ||
    die "$0: Failed to set property - $LJ::Simple::error\n";

=cut
sub Setprop_unknown8bit($$$) {
  my ($self,$event,$data)=@_;
  $LJ::Simple::error="";
  return $self->Setprop_general($event,"unknown8bit","Setprop_unknown8bit","bool",$data);
}


=pod

=item $lj->PostEntry(\$event)

Submit a journal entry into the LiveJournal system. This requires you to have
set up the journal entry with C<$lj->NewEntry()> and to have at least called
C<$lj->SetEntry()>.

On success a list containing the following is returned:

 o The item_id as returned by the LiveJournal server
 o The anum as returned by the LiveJournal server
 o The item_id of the posted entry as used in HTML - that is the
   value of C<($item_id * 256) + $anum)>

On failure C<undef> is returned.

  # Build the new entry
  my %Event;
  $lj->NewEntry(\%Event) ||
    die "$0: Failed to create new journal entry - $LJ::Simple::error\n";

  # Set the journal entry
  $lj->SetEntry(\%Event,"foo") ||
    die "$0: Failed set journal entry - $LJ::Simple::error\n";

  # And post it
  my ($item_id,$anum,$html_id)=$lj->PostEntry(\%Event);
  defined $item_id ||
    die "$0: Failed to submit new journal entry - $LJ::Simple::error\n";

=cut
##
## PostEntry - actually submit a journal entry.
##
sub PostEntry($$) {
  my $self=shift;
  my ($event)=@_;
  $LJ::Simple::error="";
  if (ref($event) ne "HASH") {
    $LJ::Simple::error="CODE: Not given a hash reference";
    return undef;
  }
  if (!exists $event->{"__new_entry"}) {
    $LJ::Simple::error="CODE: NewEntry not called";
    return undef;
  }

  ## Blat any key in $event which starts with a double underscore
  map {/^__/ && delete $event->{$_}} (keys %{$event});

  if (!defined $event->{event}) {
    $LJ::Simple::error="CODE: No journal entry set - call SetEntry() or AddToEntry() first";
    return undef;
  }

  ## Blat any entry in $self->{event} with an undef value
  map {defined $event->{$_} || delete $event->{$_}} (keys %{$event});

  ## Finally send the actual request
  my %Resp=();
  $self->SendRequest("postevent",$event,\%Resp) || return undef;

  if (!exists $Resp{itemid}) {
    $LJ::Simple::error="LJ server did not return itemid";
    return undef;
  }
  if (!exists $Resp{anum}) {
    $LJ::Simple::error="LJ server did not return anum";
    return undef;
  }

  return ($Resp{itemid},$Resp{anum},($Resp{itemid} * 256) + $Resp{anum});
}


=pod

=item $lj->DeleteEntry($item_id)

Delete an entry from the LiveJournal system which has the given C<item_id>.
On success C<1> is returned; on failure C<0> is returned.

Example:

  $lj->DeleteEntry($some_item_id) ||
    die "$0: Failed to delete journal entry - $LJ::Simple::error\n";

=cut
sub DeleteEntry($$) {
  my $self=shift;
  my ($item_id) = @_;
  my %Event=(
	itemid	=>	$item_id,
	event	=>	"",
  );
  return $self->SendRequest("editevent",\%Event,undef);
}

##### Start of helper functions

##
## A helper function which takes a key and value pair;
## both are encoded for HTTP transit.
##
sub EncVal($$) {
  my ($key,$val)=@_;
  $key=~s/\s/\+/go;
  $key=~s/([^a-z0-9+])/sprintf("%%%x",ord($1))/egsi;
  $val=~s/\s/\+/go;
  $val=~s/([^a-z0-9+])/sprintf("%%%x",ord($1))/egsi;
  return "$key=$val";
}

##
## Actually make the LJ request; could be called directly, but isn't
## documented.
##
## The first argument is the the mode to use. The list of currently
## supported modes is:
##  o login
##  o postevent
##
## The second argument is a hash reference to arguments specific to the
## mode.
##
## The third argument is a reference to a hash which contain the response
## from the LJ server. This can be undef.
##
## Returns 1 on success, 0 on failure. On failure $LJ::Simple::error is
## populated.
##
sub SendRequest($$$$) {
  my ($self,$mode,$args,$req_hash)=@_;
  $LJ::Simple::error="";
  $self->{request}={};
  if (ref($args) ne "HASH") {
    $LJ::Simple::error="INTERNAL: SendRequest() not given hashref for arguments";
    return 0;
  }
  if ((defined $req_hash) && (ref($req_hash) ne "HASH")) {
    $LJ::Simple::error="INTERNAL: SendRequest() not given hashref for responses";
    return 0;
  }
  $mode=lc($mode);
  my @request=(
	"mode=$mode",
	EncVal("user",$self->{auth}->{user}),
  );
  if (exists $self->{auth}->{hash}) {
    push(@request,EncVal("hpassword",$self->{auth}->{hash}));
  } else {
    push(@request,EncVal("password",$self->{auth}->{pass}));
  }
  push(@request,
	"ver=0",
  );
  if ($mode eq "login") {
    push(@request,EncVal("clientversion","Perl-LJ::Simple/$VERSION"));
    if ((exists $args->{moods}) && ($args->{moods} == 1)) {
      push(@request,EncVal("getmoods",0));
    }
    if ((exists $args->{getpickws}) && ($args->{getpickws} == 1)) {
      push(@request,EncVal("getpickws",1));
      push(@request,EncVal("getpickwurls",1));
    }
  } elsif ( ($mode eq "postevent")
         || ($mode eq "editevent") ) {
    my ($k,$v);
    while(($k,$v)=each %{$args}) {
      push(@request,EncVal($k,$v));
    }
  } else {
    $LJ::Simple::error="INTERNAL: SendRequest() given unsupported mode \"$mode\"";
    return 0;
  }
  my $req=join("&",@request);
  my $ContLen=length($req);

  ## Now we've got the request ready, time to start talking to the web
  # Work out where we're talking to and the URI to do it with
  my $server=$self->{lj}->{host};
  my $host=$server;
  my $port=$self->{lj}->{port};
  my $uri="/interface/flat";
  if (defined $self->{proxy}) {
    $uri="http://$server:$port$uri";
    $server=$self->{proxy}->{host};
    $port=$self->{proxy}->{port};
  }

  # Prepare the HTTP request now we've got the URI
  my @HTTP=(
	"POST $uri HTTP/1.0",
	"Host: $host",
	"Content-type: application/x-www-form-urlencoded",
	"Content-length: $ContLen",
  );
  if ($self->{fastserver}) {
    push(@HTTP,"Cookie: ljfastserver=1");
  }
  push(@HTTP,
	"",
	$req,
	"",
  );

  # Prepare the socket
  my $proto=getprotobyname("tcp");
  socket(SOCK,PF_INET,SOCK_STREAM,$proto);

  # Resolve the server name we're connecting to
  my $addr=inet_aton($server);
  if (!defined $addr) {
    $LJ::Simple::error="Failed to resolve server $server";
    return 0;
  }
  my $sin=sockaddr_in($port,$addr);

  my $ip_addr=join(".",unpack("CCCC",$addr));

  if ($LJ::Simple::protocol) {
    print STDERR "Connecting to $server [$ip_addr]\n";
    print STDERR "Lines starting with \"-->\" is data SENT to the server\n";
    print STDERR "Lines starting with \"<--\" is data RECEIVED from the server\n";
  }

  # Connect to the server
  if (!connect(SOCK,$sin)) {
    $LJ::Simple::error="Failed to connect to $server - $!";
    return 0;
  }

  ($LJ::Simple::protocol) &&
     print STDERR "Connected to $server [$ip_addr]\n";

  # Send the HTTP request
  foreach (@HTTP) {
    my $line="$_\r\n";
    my $len=length($line);
    my $pos=0;
    my $fail=0;
    while($pos!=$len) {
      my $nbytes=syswrite(SOCK,$line,$len,$pos);
      if (!defined $nbytes) {
	if ( ($! == EAGAIN) || ($! == EINTR) ) {
          $fail++;
          if ($fail>4) {
            $LJ::Simple::error="Write to socket failed with EAGAIN/EINTR $fail times";
            shutdown(SOCK,2);
            close(SOCK);
            return 0;
          }
          next;
        } else {
          $LJ::Simple::error="Write to socket failed - $!";
          shutdown(SOCK,2);
          close(SOCK);
          return 0;
        }
      }
      $pos+=$nbytes;
    }
    ($LJ::Simple::protocol) &&
      print STDERR "--> $_\n";
  }

  # Read the response from the server - use select()
  my ($rin,$rout,$eout)=("","","");
  vec($rin,fileno(SOCK),1) = 1;
  my $ein = $rin;
  my $response="";
  my $done=0;
  while (!$done) {
    my $nfound = select($rout=$rin,undef,$eout=$ein,$LJ::Simple::timeout);
    if ($nfound!=1) {
      $LJ::Simple::error="Failed to receive data from $server [$ip_addr]";
      shutdown(SOCK,2);
      close(SOCK);
      return 0;
    }
    my $resp="";
    my $nbytes=sysread(SOCK,$resp,$LJ::Simple::buffer);
    if (!defined $nbytes) {
      $LJ::Simple::error="Error in getting data from $server [$ip_addr] - $!";
      shutdown(SOCK,2);
      close(SOCK);
      return 0;
    } elsif ($nbytes==0) {
      $done=1;
    } else {
      $response=join("",$response,$resp);
      if ($LJ::Simple::protocol) {
        foreach (split(/[\r\n]{1,2}/,$resp)) {
          print STDERR "<-- $_\n";
        }
      }
    }
  }
  
  # Shutdown the socket
  if (!shutdown(SOCK,2)) {
    $LJ::Simple::error="Failed to shutdown socket - $!";
    return 0;
  }

  # Close the socket
  close(SOCK);

  ## We've got the response from the server, so we now parse it
  # First remove all \r's
  $response=~s/\r//go;

  # Split into headers and body
  my ($http,$body)=split(/\n\n/,$response,2);

  # First lets see if we got a valid response
  $self->{request}->{http}={};
  $self->{request}->{http}->{headers}=[(split(/\n/,$http))];
  my $srv_resp=$self->{request}->{http}->{headers}->[0];
  $srv_resp=~/^HTTP\/[^\s]+\s([0-9]+)\s+(.*)/;
  my ($srv_code,$srv_msg)=($1,$2);
  $self->{request}->{http}->{code}=$srv_code;
  $self->{request}->{http}->{msg}=$srv_msg;
  if ($srv_code != 200) {
    $LJ::Simple::error="HTTP request failed with $srv_code $srv_msg";
    return 0;
  }

  # We did, so lets pull in the LJ stuff for processing
  $self->{request}->{lj}={};

  # The response from LJ takes the form of a key\nvalue\n
  $done=0;
  while (!$done) {
    if ($body=~/^([^\n]+)\n([^\n]+)\n(.*)$/so) {
      $self->{request}->{lj}->{lc($1)}=$2;
      $body=$3;
    } else {
      $done=1;
    }
  }

  # Got it into a hash - lets see if we made a successful request
  if ( (!exists $self->{request}->{lj}->{success}) ||
       ($self->{request}->{lj}->{success} ne "OK") ) {
    my $errmsg="No error returned by LJ system";
    if (exists $self->{request}->{lj}->{errmsg}) {
      $errmsg=$self->{request}->{lj}->{errmsg};
    }
    $LJ::Simple::error="LJ request failed: $errmsg";
    return 0;
  }

  # We did!
  # Now to populate the hash we were given (if asked to)
  if (defined $req_hash) {
    %{$req_hash}=();
    my ($k,$v);
    while(($k,$v)=each %{$self->{request}->{lj}}) {
      $req_hash->{$k}=$v;
    }
  }

  return 1;
}

##
## Output debugging info
##
sub Debug(@) {
  ($LJ::Simple::debug) || return;
  my $msg=join("",@_);
  foreach (split(/\n/,$msg)) {
    print STDERR "DEBUG> $_\n";
  }
}


##
## Dump out a list recursively. Will call dump_hash
## for any hash references in the list.
##
## Generally used for debugging
##
sub dump_list($$) {
  my ($lr,$sp)=@_;
  my $le="";
  my $res="";
  foreach $le (@{$lr}) {
    if (ref($le) eq "HASH") {
      $res="$res$sp\{\n";
      $res=$res . dump_hash($le,"$sp  ");
      $res="$res$sp},\n";
    } elsif (ref($le) eq "ARRAY") {
      $res="$res$sp\[\n" . dump_list($le,"$sp  ") . "$sp],\n";
    } else {
      my $lv=$le;
      if (defined $lv) {
        $lv=quotemeta($lv);
        $lv=~s/\\-/-/go;
        $lv="\"$lv\"";
      } else {
        $lv="undef";
      }
      $res="$res$sp$lv,\n";
    }
  }
  return $res;
}

##
## Dump out a hash recursively. Will call dump_list
## for any list references in the hash values.
##
## Generally used for debugging
##
sub dump_hash($$) {
  my ($hr,$sp)=@_;
  my ($k,$v)=();
  my $res="";
  while(($k,$v)=each %{$hr}) {
    $k=quotemeta($k);
    $k=~s/\\-/-/go;
    if (ref($v) eq "HASH") {
      $res="$res$sp\"$k\"\t=> {\n";
      $res=$res . dump_hash($v,"$sp  ");
      $res="$res$sp},\n";
    } elsif (ref($v) eq "ARRAY") {
      $res="$res$sp\"$k\"\t=> \[\n" . dump_list($v,"$sp  ") . "$sp],\n";
    } else {
      if (defined $v) {
        $v=quotemeta($v);
        $v="\"$v\"";
      } else {
        $v="undef";
      }
      my $out="$sp\"$k\"\t=> $v,";
      $res="$res$out\n";
    }
  }
  return $res;
}

1;
__END__

=pod

=back

=head1 EXAMPLE

The following simple example logs into the LiveJournal server and
posts a simple comment.

  use LJ::Simple;

  # Log into the server
  my $lj = new LJ::Simple ({
          user    =>      "test",
          pass    =>      "test",
          site    =>      undef,
          proxy   =>      undef,
        });
  (defined $lj)
    || die "$0: Failed to log into LiveJournal: $LJ::Simple::error\n";
  
  # Prepare the event
  my %Event=();
  
  # Put in the entry
  my $entry=<<EOF;
  A simple entry made using <tt>LJ::Simple</tt> version $LJ::Simple::VERSION
  EOF
  $lj->SetEntry(\%Event,$entry)
    || die "$0: Failed to set entry: $LJ::Simple::error\n";
  
  # Say we are happy
  $lj->SetMood(\%Event,"happy")
    || die "$0: Failed to set mood: $LJ::Simple::error\n";
  
  # Don't allow comments
  $lj->Setprop_nocomments(\%Event,1);
  
  my ($item_id,$anum,$html_id)=$lj->PostEntry(\%Event);
  (defined $item_id)
    || die "$0: Failed to post journal entry: $LJ::Simple::error\n";
  
=head1 AUTHOR

Simon Burr E<lt>simes@bpfh.netE<gt>

=head1 SEE ALSO

perl

=head1 LICENSE

Copyright (c) 2002, Simon Burr E<lt>F<simes@bpfh.net>E<gt>
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

  * Redistributions of source code must retain the above copyright notice,
    this list of conditions and the following disclaimer. 
  * Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution. 
  * Neither the name of the author nor the names of its contributors may
    be used to endorse or promote products derived from this software
    without specific prior written permission. 

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut
