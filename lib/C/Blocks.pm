package C::Blocks;

use strict;
use warnings;

# Development tool. If *this* *module* is in a blib, then I'm developing.
# In that case, I would like to use a development tcc if available.
#BEGIN {
#	my $mod_path = $INC{'C/Blocks.pm'};
#	if ($mod_path =~ /blib/) {
#		eval { require inc::Alien::TinyCC };
#		die $@ if $@ =~ /LD_LIBRARY_PATH/;
#		require Alien::TinyCC;
#	}
#}
use Alien::TinyCCx;

use XSLoader;

# Use David Golden's version numbering suggestions. Note that we have to call
# the XSLoader before evaling the version string because XS modules check the
# version *string*, not the version *number*, at boot time.
our $VERSION = "0.000_001";
XSLoader::load('C::Blocks', $VERSION);
$VERSION = eval $VERSION;

our (@__code_cache_array, @__symtab_cache_array);
our $default_compiler_options = "-Wall -D_C_BLOCKS_OS_$^O ";
our $compiler_options = $default_compiler_options;
our $library_to_link;
our ($_add_msg_functions, $_msg);

sub import {
	my $class  = shift;
	my $caller = caller;
	no strict 'refs';
	*{$caller.'::cblock'} = sub () {};
	*{$caller.'::csub'} = sub () {};
	*{$caller.'::cshare'} = sub () {};
	*{$caller.'::clex'} = sub () {};
	_import();
}

# The XS code for the keyword parser makes sure that if a module invokes cshare,
# it is also a descendent of C::Blocks::libloader. The only reason it does that
# is to make sure that this function has a good chance of getting invoked when
# somebody tries to use the module. This function adds its module's symtab list
# (a series of pointers) to the calling lexical scope's hints hash. These
# symtabs are consulted during compilation of cblock declarations in the calling
# lexical scope.
sub C::Blocks::libloader::import {
	# Get the name of the module that is being imported.
	my ($module) = @_;
	
	# Get the use'd module's symbol table list
	my $symtab_list = do {
		 no strict 'refs';
		 ${"${module}::__cblocks_extended_symtab_list"}
	};
	
	# add the symtab list to the calling context's hints hash
	$^H{"C::Blocks/extended_symtab_tables"} .= $symtab_list;
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
 cshare {
     /* This function can be imported into other lexical scopes. */
     void say_hi() {
         printf("Hello from My::Fastlib\n");
     }
 }
 
 package main;
 
 # Pull say_hi into this scope
 use My::Fastlib;
 
 cblock {
     print_location(3);
     say_hi();
 }
 
 print "All done!\n"; 

=head1 ALPHA

This project is currently in alpha. It does not fully implement some of the
key features; it does not support multiple threads.

=head1 DESCRIPTION

This module has a number of goals. First, it provides a way to write and execute
blocks of C code directly in your Perl code. Second, it provides a mechanism for
defining C functions and global variables, callable from your blocks of C code,
that are I<lexically> scoped, i.e. they become inaccessible when you leave the
Perl scope in which they were declared. Third, it provides a mechanism for
defining C functions and global variables that can be I<lexically exported>, and
used in the C blocks of the calling package.

C<C::Blocks> achieves all of these goals by providing new keywords that
demarcate blocks of C code. There are essentially two types of blocks: those
that indicate a procedural block of C code that should be run, and those that
declare C functions, variables, etc., that are used by other blocks.

=head2 Procedural Blocks

When you want to execute a block of procedural C code, use a C<cblock>:

 use C::Blocks;
 print "1\n";
 
 cblock {
     printf("2\n");
 }
 
 print "3\n";

This produces the output

 1
 2
 3

Code in C<cblock>s have access to declarations contained in any C<clex> or
C<cshare> blocks that precede it. These blocks are discussed next.

If you use a Perl variable in your C<cblock>, it automatically pull in
L<C::Blocks::libperl>, and the reference to the variable will be replaced with
the C<SV*>, C<AV*>, or C<HV*> that refers to the variable by the same name:

 use C::Blocks;
 my $message = 'Greetings!';
 
 cblock {
     printf("The message variable contains: [%s]\n",
         SvPVbyte_nolen($message));
     sv_setnv($message, 5.938);
 }
 
 print "After the cblock, message is [$message]\n";

This produces the output (rather it should, but does not yet)

 The message variable contains: [Greetings!]
 After the clobkc, message is [5.938]

Any method in L<Perl's C API|perlapi> is available.

=over

XXX back this up with benchmarks:

C<C::Blocks> is currently implemented using the Tiny C Compiler, a compiler
written to I<compile> fast, but not necessarily produce blazingly fast machine
code. As such, the above code block is not likely to run much faster than the
equivalent Perl code. In general, micro-optimizations that replace a handful of
Perl statements with their C-API equivalents are not likely to lead to
performance gains.

Eventually I plan for C<C::Blocks> to be a front-end to multiple back-ends, one
of which would be L<Inline::C>, another of which would be an author tool that
extracts the blocks and builds an XS file and PMC file. Both of these would use
the system's optimized compiler (i.e. gcc) to produce much faster machine code.
In that case, such micro-optimizations are likely to lead to better performance
gains.

XXX really need to back this up with benchmarks

Rather than focus on micro-optimizations of Perl operations on Perl structures,
you should instead use C<C::Blocks> to write code that performs C operations on
C structures. But then how do you declare your C data structures? And more
importantly, how do you package those structures into a library in order to
share those structures with others? That's what I discuss next.

=back

=head2 Private C Declarations

A great deal of C's power lies in your ability to define compact data structures
and reusable chunks of code. When you wish to declare such data structures or
functions, use a C<clex> block. (If you wish to write a module full of functions
and data structures for I<others> to use, you will use a C<cshare> block, which
I'll explain shortly.) The declarations in such a block are available to any
other C<cblock>s, C<clex>s, and C<cshare>s that share the same lexical scope as
the C<clex> block.

Such a block might look like this:

 use C::Blocks::libs qw(perl math); # libmath does not exist yet!!!
 
 clex {
     typedef struct _point_t {
         double x;
         double y;
     } point;
     
     double point_distance_from_origin (point * loc) {
         return sqrt(loc->x * loc->x + loc->y * loc->y);
     }
     
     /* Assume they have an SV packed with a point struct */
     point * point_from_SV(SV * point_SV) {
         return (point*)SvPVbyte_nolen(point_SV);
     }
 }

Notice that I need to include C<libperl> because I use structs and functions
defined in the Perl C API (C<SV*> and C<SvPVbyte_nolen>). I need to include
C<libmath> because I use C<sqrt>. The Perl C API, in particular, is not
included automatically. It is only included automatically if a C<cblock>
contains sigil'ed variables.

Later in your file, you could make use of the functions in a C<cblock> such as:

 # Assume pairs is ($x1, $y1, $x2, $y2, $x3, $y3, ...)
 # Create a C array of doubles, which is equivalent to an
 # array of points with half as many array elements
 my $points = pack 'd*', @pairs;
 
 # Calculate the average distance to the origin:
 my $avg_distance;
 cblock {
     point * points = point_from_SV(*point_SV_p);
     int N_points = av_len(@pairs) / 2 + 0.5;
     double length_sum = 0;
     for (i = 0; i < N_points; i++) {
         length_sum += point_distance_from_origin(points + i);
     }
     sv_setnv($avg_distance, length_sum / N_points);
 }
 
 print "Average distance to origin is $avg_distance\n";

With the Tiny C Compiler backend, this works copying the C symbol table and
storing a reference to it in a lexically scoped location. Later C blocks consult
the symbol tables that are referenced in the current lexical scope, and copy
individual symbols on an as-needed basis into their own symbol tables.

This code could be part of a module, but none of the C declarations would be
available to modules that C<use> this module. C<clex> blocks let you declare
private things to be used only within the lexical scope that encloses the
C<clex> block. If you want to share a C API, for others to use in their own
C<cblock> and C<clex> code, you should look into the next type of block:
C<cshare>.

=head2 Shared C Declarations

I mentioned that the symbol tables of C<clex> blocks are copied and a lexically
scoped reference is made to the copy. The same is true of C<cshare> blocks, but
a reference is also stored in the current package. Later, when somebody C<use>es
the module (or otherwise calls the package's C<import> method), the references
to all C<cshare> symbol tables are copied into the caller's lexically scoped set
of symbol tables.

For example, if the C<clex> block given in the L<private declarations
example|/Private C Declarations> were a C<cshare> block in a module called
F<My/Module.pm>, others could use the functions and struct definition by saying

 use My::Module;

They would then be able to call C<point_from_SV>. Equally important, access to
those declarations is lexically scoped. Thus:

 {
     use My::Module;
     cblock {
         point * p = point_from_SV($var); /* no problem */
     }
 }
 
 cblock {
     point * p = point_from_SV($var); /* dies: unknown type "point" */
 }

The second C<cblock> is outside of the block in which C<My::Module> was C<use>d.
This means that its reference of symbol tables does not include the declarations
from C<My::Module>.

=head2 Breaking Sharing

How do shared C declarations work? When C<C::Blocks> encounters a C<cshare>, it
appends C<C::Blocks::libloader> to the current package's C<@ISA> array. The sole
purpose of this is to provide a default C<import> method that properly copies
the symbol table references in a lexically scoped way. This can be broken in one
of two ways.

First, if you overwrite C<@ISA> by direct assignment, you will erase the
C<libloader> entry. This is easier than you might think. For example, this will
break the import mechanism:

 package Some::Code;
 our @ISA = qw(Base::Class);
 cshare {
     /* ... */
 }

The reason is that the assignment to C<@ISA> occurs when the package definition
is executed, but C<libloader> is added to C<@ISA> at compile time (like adding
it in a C<BEGIN> block).

Another way to break sharing is to provide your own C<import> method which does
not call C<C::Blocks::libloader::import>. In that case, Perl's own method
resolution will resolve to your C<import> and never call C<libloader>'s. To fix
this, you should include the following line in your C<import> method:

 sub import {
     my ($package, @args) = @_;
     ...
     C::Blocks::libloader::import($package);
 }

You could also experience this problem the other way around: you expect your
module to use an inherited C<import> method, but you only get C<libloader>'s
import behavior. You fix that by providing your own C<import> method:

 sub import {
     my ($package, @args) = @_;
     C::Blocks::libloader::import($package);
     my $method = Parent::Package->can('import');
     goto $method;  # XXX check this
 }

=head1 KEYWORDS

The way that C<C::Blocks> provides these functionalities is through lexically
scoped keywords: C<cblock>, C<clex>, C<cshare>, and C<csub>. These keywords
precede a block of C code encapsulated in curly brackets. Because these use the
Perl keyword API, they parse the C code during Perl's parse stage, so any code
errors in your C code will be caught during parse time, not during run time.

=over

=item cblock { code }

C code contained in a C<cblock> gets wrapped into a special type of C function
and compiled during the compilation stage of the surrounding Perl code. The
resulting function is inserted into the Perl op tree at the precise location of
the block and is called when the interpreter reaches this part of the code.

The code in a C<cblock> is wrapped into a function, so function and struct
declarations are not allowed. Also, variable declarations and preprocessor
definitions are confined to the C<cblock> and will not be present in later
C<cblock>s. For that sort of behavior, see C<clex>.

Variables with sigils are interpreted as referring to the C<SV*>, C<AV*>, or
C<HV*> representing the variable in the current lexical scope. If C<use strict
'vars'> is in effect, then these can only refer to lexical variables; otherwise
they can also refer to package variables.

Note: If you need to leave a C<cblock> early, you should use a C<return>
statement without any arguments.

=item clex { code }

C<clex> blocks contain function, variable, struct, enum, union, and preprocessor
declarations that you want to use in other C<cblock>, C<clex>, and C<cshare>
blocks that follow. It is important to note that these are strictly
I<declarations> that are compiled at Perl's compile time and shared with other
blocks.

Sigil variables in C<clex> blocks are not currently allowed. How these might
work is yet to be determined.

=item cshare { code }

C<cshare> blocks are just like C<clex> blocks except that the declarations can
be shared with other modules when the C<use> the current module.

Note: discuss how the import mechanism works, how it can be broken, and how to
fix it.

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

=item Make C<$var> in C blocks do something useful in C<clex>

=item Write a library like XS::Object::Magic

=item Threadsafe

The Tiny C Compiler uses lots of global variables and is therefore not
threadsafe. I would like to contribute back to the project by
encapsulating all of that global state into the compiler state object,
where it belongs. Others in the tcc community have expressed interest in
getting this done, so it is a welcome contribution.

=item Inline::C and Module::Compile backends

I would like to be able to use Inline::C or Module::Compile as back-ends to
C<C::Blocks>, rather than being restricted to the Tiny C Compiler.

=back

=head1 SEE ALSO

This module uses the Tiny C Compiler through the Alien package provided
by L<Alien::TinyCCx>. To learn more about the Tiny C Compiler, see
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

Code copyright 2013-2015 Dickinson College. Documentation copyright 2013-2015
David Mertens.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut
