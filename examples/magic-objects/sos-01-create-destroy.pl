=head1 NAME

sos-01-create-destroy.pl - exercise SOS01 creation and destruction

=head1 QUESTION

See L<SOS01> for the major question and detailed discussion of
implementation tradeoffs. The question of this script is much simpler:
does the creation and destruction code work?

=cut

use strict;
use warnings;
use SOS01;

print "=== create thing ===\n";
my $thing = SOS01->new;
print "=== destroy thing ===\n";
undef $thing;
print "=== create another thing ===\n";
$thing = SOS01->new;
print "=== copy another thing ===\n";
my $thing2 = $thing;
#use Devel::Peek;
#Dump($thing2);
print "=== destroy first copy of another thing ===\n";
undef $thing;
print "=== implicitly destroy another thing at end of script ===\n";

=head1 RESULTS

The code works as expected. Everything runs in the expected order and
with minimal call stack depth. The demise of the variables coincides
with the exact time that their reference counts should have dropped to
zero. All seems well for the moment.
