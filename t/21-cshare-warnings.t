use strict;
use warnings;
use Test::More;
use C::Blocks -noPerlAPI;
use Test::Warn;

# This tests how warnings are issued when injecting the import method

# no conflict, no warning
warning_is {eval q{
	package TestPackage1;
	cshare {
		void foo1() {
			int i;
			i = 5;
		}
	}
}} undef, 'No import, no problem!';

# redefinition warning
warning_like {eval q{
	package TestPackage2;
	sub import { }
	cshare {
		void foo1() {
			int i;
			i = 5;
		}
	}
}} qr/'import' method already found/,
	'Existence of import warns when warnings are enabled';

# silenced redefinition warning
warning_is {eval q{
	package TestPackage3;
	no warnings 'C::Blocks::import';
	sub import { }
	cshare {
		void foo1() {
			int i;
			i = 5;
		}
	}
}} undef, 'Explicitly turning off C::Blocks::import avoids warning';

package main;
done_testing;
