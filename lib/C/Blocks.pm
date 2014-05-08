package C::Blocks;

use strict;
use warnings;
use Alien::TinyCC;
use XSLoader;

# Use David Golden's version numbering suggestions. Note that we have to call
# the XSLoader before evaling the version string because XS modules check the
# version *string*, not the version *number*, at boot time.
our $VERSION = "0.000_001";
XSLoader::load('C::Blocks', $VERSION);
$VERSION = eval $VERSION;

our (@__code_cache_array);

sub import {
	my $class  = shift;
	my $caller = caller;
	no strict 'refs';
	*{$caller.'::cblock'} = sub () {};
	*{$caller.'::csub'} = sub () {};
	*{$caller.'::clib'} = sub () {};
	*{$caller.'::clex'} = sub () {};
	_import();
}

END {
	_cleanup();
}

1;

__END__

=head1 NAME

C::Blocks - embeding a fast C compiler directly into your Perl parser

=head1 SYNOPSIS

 use strict;
 use warnings;
 use C::Blocks;
 
 print "Before block\n";
 
 cblock {
     /* This is bare C code! */
     printf("From C block\n");
     int foo = 1;
     printf("foo = %d, which is %s\n", foo, (foo % 2 == 1 ? "odd" : "even"));
 }
 
 print "After first block\n";
 
 clex {
     /* This function will only be visible to other c code blocks in this
      * lexical scope. */
     
     void print_location(int block_numb) {
         printf("From block number %d\n", block_numb);
     }
 }
 
 cblock {
     print_location(2);
 }
 
 # Finally, we can declare xsubs inline with this:
 csub my_xsub {
     /* This one really needs quite a bit more work... */
     
     /* shift off args? Allow for $_[0] syntax? */
 }
 
 my_xsub('called from perl!');
 
 package My::Fastlib;
 clib {
     /* This function can be imported into other lexical scopes. */
     void say_hi() {
         printf("Hello from My::Fastlib\n");
     }
 }
 
 package main;
 
 # Pull say_hi into this scope
 cuse My::Fastlib;
 
 cblock {
     print_location(3);
     say_hi();
 }
 
 print "All done!\n"; 

=head1 ALPHA

This project is currently in alpha. I say this not because I expect the
API to I<change> much (if at all), but because I expect the API to
I<grow> substantially. Presently you cannot use the Perl C API in your C
blocks, which makes it nearly useless for most purposes. Another
substantial limitation is that the compiler uses lots of global
variables, so if you try to use this in a multi-threaded context and you
try to compile C code simultaneously in multiple threads, it'll likely
blow up.

=head1 DESCRIPTION

This module uses Perl's pluggable keyword API to add a few new keywords:
C<cblock>, C<cdecl>, and C<csub>. These keywords precede a block of C code
encapsulated in curly brackets.

=over

=item cblock { code }

C code contained in a cblock gets wrapped into a special type of C function and
compiled during the compilation stage of the surrounding Perl code. The
resulting function is inserted into the Perl op tree at the precise location of
the block and is called when the interpreter reaches this part of the code.

The behavior of a cblock is somewhat like writing C code that is included in an
implicit main() function. In particular, there is no way to declare functions,
data structures, or typedefs. Use a C<cdecl> for that.

You should not include a return statement in this code.

=item cdecl { code }

C code contained in a cdecl block is extracted from the rest of the Perl source
code and compiled. Any later C<cblock>, C<cdecl>, or C<csub> has access to the
functions, macros, typedefs, structs, enums, etc.

At most, sigil interpolation would only be allowed in functions, and even then
only for package globals, not lexicals. This is because any lexical variables
that might be used would need to be closed over, and I am not sure how to do
that correctly.

=item csub name { code }

C code contained in a csub block is wrapped into an xsub function definition.
This means that after this code is compiled, it is accessible just like any
other xsub.

Interpolation of sigils is open to discussion. Sigils such as C<$_[0]> could
be very useful for manipulating the stack, for example.

=back

=head1 GOALS

My three major goals for this project are:

=over

=item Perl C API

None of the Perl C API is available. It's hard to do much without being
able to interact with Perl data.

=item Make C<$var> in C blocks do something useful

I would like to be able to say something like this, and have it Do What
I Mean:

 my $var = 'hello';
 print "Var is initially $var\n";
 C {
     sv_setiv($var, 5);
 }
 print "Now var is $var\n";

In addition to needing Perl's C API, I would need to modify the C parser
to identify Perl-like variables and insert the correct code.

=item Extension API

I would like to allow for lexically scoped extensions to add functions
and struct definitions. This will require a bit of hacking on TCC's
symbol table machinery, so will likely take a bit of time and effort.

=item Threadsafe

The Tiny C Compiler uses lots of global variables and is therefore not
threadsafe. I would like to contribute back to the project by
encapsulating all of that global state into the compiler state object,
where it belongs. Others in the tcc community have expressed interest in
getting this done, so it is a welcome contribution.

=item Extraction for optimized compiling

Right now the C code gets compiled at Perl's parse time. However, for
code that doesn't change, it would be nice to prototype the code using
C::Blocks, then extract the op-code definitions into an XS file to be
compiled by an optimized compiler (such as gcc). This would require
writing a second pluggable keyword module that takes the same input and
generates XS output instead of compiling the code.

=back

=head1 SEE ALSO

This module uses the Tiny C Compiler through the Alien package provided
by L<Alien::TinyCC>. To learn more about the Tiny C Compiler, see
L<http://bellard.org/tcc/> and L<http://savannah.nongnu.org/projects/tinycc>.

For other ways of compiling C code in your Perl scripts, check out
L<Inline::C>, L<C::TinyCompiler>, and L<XS::TCC>.

=head1 AUTHOR

David Mertens (dcmertens.perl@gmail.com)

=head1 BUGS

Please report any bugs or feature requests for the Alien bindings at the
project's main github page:
L<http://github.com/run4flat/C-Blocks/issues>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc C::Blocks

You can also look for information at:

=over 4

=item * The Github issue tracker (report bugs here)

L<http://github.com/run4flat/C-Blocks/issues>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/C-Blocks>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/C-Blocks>

=item * Search CPAN

L<http://p3rl.org/C::Blocks>
L<http://search.cpan.org/dist/C-Blocks/>

=back

=head1 ACKNOWLEDGEMENTS

This would not be possible without the amazing Tiny C Compiler or the
Perl pluggable keyword work. My thanks goes out to developers of both of
these amazing pieces of technology.

=head1 LICENSE AND COPYRIGHT

Code copyright 2013 Dickinson College. Documentation copyright 2013 David
Mertens.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut
