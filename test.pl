# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################
use Test;
BEGIN { plan tests => 47 };
use LJ::Simple;
ok(1); # If we made it this far, we're ok.
#########################

## Test object creation via new - should fail
my $lj = new LJ::Simple();
if (!defined $lj) { ok(1) } else { ok(0) }

## Test object creation via login - should fail
$lj = LJ::Simple->login();
if (!defined $lj) { ok(1) } else { ok(0) }

if (1) {
#  $LJ::Simple::debug=1;
#  $LJ::Simple::protocol=1;
}

## Test object creation by going to a site not running LJ
$lj = new LJ::Simple ({
	user	=>	"test",
	pass	=>	"test",
	site	=>	"httpd.apache.org",
	proxy	=>	undef,
      });
if (defined $lj) { 
  ok($LJ::Simple::error,'/HTTP request failed/');
} else {
  ok(1);
}

## Test object creation with what is (hopefully) an invalid username
$lj = new LJ::Simple ({
	user	=>	"testmmeekmooo",
	pass	=>	"test",
	site	=>	undef,
	proxy	=>	undef,
      });
if (defined $lj) { 
  ok($LJ::Simple::error,'/LJ login failed: Invalid username/');
} else {
  ok(1);
}

## Test object creation with a valid user, but invalid password
$lj = new LJ::Simple ({
	user	=>	"test",
	pass	=>	"testy",
	site	=>	undef,
	proxy	=>	undef,
      });
if (defined $lj) { 
  ok($LJ::Simple::error,'/LJ login failed: Invalid password/');
} else {
  ok(1);
}

## Test object creation with a valid username and password
$lj = new LJ::Simple ({
	user	=>	"test",
	pass	=>	"test",
	site	=>	undef,
	proxy	=>	undef,
      });
if (defined $lj) { 
  ok(1);
} else {
  ok(0);
}

my $msg=$lj->message();
ok(1);

my %Moods=();
if (!defined $lj->moods(\%Moods)) {
  ok(0);
} else {
  ok(1);
}

my @communities = $lj->communities();
ok(1);

my %Groups=();
if (!defined $lj->groups(\%Groups)) {
  if ($LJ::Simple::error=~/ - none defined/) {
    ok(1);
  } else {
    ok(0);
  }
} else {
  ok(1);
}

my %pictures=();
$lj->pictures(\%pictures);
ok(1);

my %Event=();

## Ensure that stuff for posting journal entrie doesn't work until
## NewEntry is called
if (!defined $lj->PostEntry(\%Event)) {
  if ($LJ::Simple::error=~/Failed to post entry/){ok(1);}else{ok(0);}
} else { ok(0); }
if (!$lj->SetDate("")) {
  if ($LJ::Simple::error=~/Not given a hash reference/){ok(1);}else{ok(0);}
} else { ok(0); }
if (!$lj->Setprop_backdate("",1)) {
  if ($LJ::Simple::error=~/Not given a hash reference/){ok(1);}else{ok(0);}
} else { ok(0); }

if (!$lj->NewEntry(\%Event)) {
  ok(0);
} else {
  ok(1);
}


## Post it - we are expecting an error due to no entry being present
if (!defined $lj->PostEntry(\%Event)) {
 if ($LJ::Simple::error=~/no journal entry/){ok(1);}else{ok(0);}
} else {
  ok(0);
}

## Playing with shared journals
# Set to shared journal we assume doesn't exist
if (!$lj->UseJournal(\%Event,"communitydoesnotexisthopefully")) {
 if ($LJ::Simple::error=~/user unable to post/){ok(1);}else{ok(0);}
} else {
  ok(0);
}
# Set to shared journal which should exist
if (!$lj->UseJournal(\%Event,"test2")) { ok(0) } else { ok(1) }

## Setting date... we use $lj->{event}->{__timet} here
# Set to current time
if (!$lj->SetDate(\%Event,undef)) {
  ok(0);
} else {
  my ($t,$r)=(time(),$Event{__timet});
  if ($t==$r) { ok(1); }
  elsif (($t>$r)&&($t<=($r+5))) { ok(1); }
  else { ok(0); }
}
# Set to current time less an hour
if (!$lj->SetDate(\%Event,-3600)) {
  ok(0);
} else {
  my ($t,$r)=(time()-3600,$Event{__timet});
  if ($t==$r) { ok(1); }
  elsif (($t>$r)&&($t<=($r+5))) { ok(1); }
  else { ok(0); }
}

## Set properties
if (!$lj->Setprop_backdate(\%Event,1)) { ok(0) } else { ok(1) }
if (!$lj->Setprop_current_mood(\%Event,"Meep")) { ok(0) } else { ok(1) }
if (!$lj->Setprop_current_mood_id(\%Event,12)) { ok(0) } else { ok(1) }
if (!$lj->Setprop_current_music(\%Event,"Collected dance")) { ok(0) } else { ok(1) }
if (!$lj->Setprop_preformatted(\%Event,1)) { ok(0) } else { ok(1) }
if (!$lj->Setprop_nocomments(\%Event,1)) { ok(0) } else { ok(1) }
if (!$lj->Setprop_noemail(\%Event,1)) { ok(0) } else { ok(1) }
if (!$lj->Setprop_unknown8bit(\%Event,1)) { ok(0) } else { ok(1) }

if (!$lj->Setprop_picture_keyword(\%Event,"Some photo")) {
  if ($LJ::Simple::error=~/Picture keyword not associated/) {ok(1)} else {ok(0)}
} else {
  ok(0);
}

## Set permissions
if (!$lj->SetProtectPrivate(\%Event)) { ok(0) } else { ok(1) }
if (!$lj->SetProtectFriends(\%Event)) { ok(0) } else { ok(1) }
# This should fail
if ($lj->SetProtectGroups(\%Event)) { ok(0) } else { ok(1) }
# As should this
if (!$lj->SetProtectGroups(\%Event,"meep foo bar baz")) {
  if ($LJ::Simple::error=~/Group "[^"]*" does not exist/) {ok(1)} else {ok(0)}
} else {
  ok(0);
}
# This should work
if (!$lj->SetProtectGroups(\%Event,"Communities")) { ok(0) } else { ok(1) }

## Set subject
if ($lj->SetSubject(\%Event,"a"x256)) { ok(0) } else { ok(1) }
if ($lj->SetSubject(\%Event,"\n")) { ok(0) } else { ok(1) }
if (!$lj->SetSubject(\%Event,"Meep")) { ok(0) } else { ok(1) }

## Set entry
if (!$lj->SetEntry(\%Event,"Some val")) { ok(0) } else { ok(1) }
if (!$lj->AddToEntry(\%Event,"Other val")) { ok(0) } else { ok(1) }
if ($Event{event} ne "Some val\nOther val") { ok(0) } else { ok(1) }

my @stuff=("Line 1","Line 2","Line 3");
my @ts=(@stuff);
if (!$lj->SetEntry(\%Event,@stuff)) {
  ok(0) 
} else {
  if ($Event{event} eq join("\n",@ts)) { ok(1) } else { ok(0) }
}
@stuff=("Line 4","Line 5","Line 6");
push(@ts,@stuff);
if (!$lj->AddToEntry(\%Event,@stuff)) {
  ok(0) 
} else {
  if ($Event{event} eq join("\n",@ts)) { ok(1) } else { ok(0) }
}

## Now re-create an entry
if (!$lj->NewEntry(\%Event)) {
  ok(0);
} else {
  ok(1);
}

my $entry=<<EOF;
Test of <tt>LJ::Simple</tt> version $LJ::Simple::VERSION
EOF
if (!$lj->SetEntry(\%Event,$entry)) { ok(0) } else { ok(1) }

$lj->SetMood(\%Event,"happy");
$lj->Setprop_nocomments(\%Event,1);

## Finally fully test a post
my ($item_id,$anum,$html_id)=$lj->PostEntry(\%Event);
if (!defined $item_id) {
  ok(0);
} else {
  ok(1);
}



## Be nice and remove the test entry
if (!$lj->DeleteEntry($item_id)) { ok(0) } else { ok(1) }

