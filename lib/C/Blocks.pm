########################################################################
                       package C::Blocks;
########################################################################

use strict;
use warnings;
use warnings::register qw(import compiler linker);

use Alien::TinyCCx;
use XSLoader;

# Use David Golden's version numbering suggestions. Note that we have to call
# the XSLoader before evaling the version string because XS modules check the
# version *string*, not the version *number*, at boot time.
our $VERSION = "0.05";
XSLoader::load('C::Blocks', $VERSION);
$VERSION = eval $VERSION;

our (@__code_cache_array, @__symtab_cache_array, @__dll_list_array);
our $default_compiler_options = "-Wall -D_C_BLOCKS_OS_$^O ";
our $compiler_options = $default_compiler_options;
our @libraries_to_link;
our ($_add_msg_functions, $_msg);

sub import {
	my $class  = shift;
	my $caller = caller;
	no strict 'refs';
	*{$caller.'::cblock'} = sub () {};
	*{$caller.'::csub'} = sub () {};
	*{$caller.'::cshare'} = sub () {};
	*{$caller.'::clex'} = sub () {};
	*{$caller.'::cisa'} = sub () {};
	_import();
}

# Provided so I can call warnings::warnif from Blocks.xs. Why can't I
# just call warnings::warnif from that code directly????  XXX
sub warnif {
	my ($category, $message) = @_;
	warnings::warnif($category, $message);
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

########################################################################
                   package C::Blocks::Type::NV;
########################################################################
use Scalar::Util;
use Carp;

our $TYPE = 'NV';
our $INIT = 'SvNV';
our $CLEANUP = 'sv_setnv';

sub check_var_types {
	my $package = shift @_;
	$@ = '';
	while (@_) {
		my ($arg_name, $arg) = splice @_, 0, 2;
		$@ .= "$arg_name is not defined\n" and next if not defined $arg;
		$@ .= "$arg_name is a reference\n" and next if ref($arg);
		$@ .= "$arg_name does not look like a number" and next
			unless Scalar::Util::looks_like_number($arg);
	}
	if ($@ eq '') {
		undef $@;
		return 1;
	}
	return 0;
}

########################################################################
               package C::Blocks::Type::double;
########################################################################
our $TYPE = 'double';
our $INIT = 'SvNV';
our $CLEANUP = 'sv_setnv';
*check_var_types = \&C::Blocks::Type::NV::check_var_types;

########################################################################
               package C::Blocks::Type::float;
########################################################################
our $TYPE = 'float';
our $INIT = 'SvNV';
our $CLEANUP = 'sv_setnv';
*check_var_types = \&C::Blocks::Type::NV::check_var_types;

########################################################################
               package C::Blocks::Type::int;
########################################################################
our $TYPE = 'int';
our $INIT = 'SvIV';
our $CLEANUP = 'sv_setiv';
*check_var_types = \&C::Blocks::Type::NV::check_var_types;

########################################################################
               package C::Blocks::Type::uint;
########################################################################
our $TYPE = 'unsigned int';
our $INIT = 'SvUV';
our $CLEANUP = 'sv_setuv';
# Should check sign, too
*check_var_types = \&C::Blocks::Type::NV::check_var_types;

# Other types:
# int2ptr
# uint2ptr

1;

__END__

=head1 NAME

C::Blocks - embeding a fast C compiler directly into your Perl parser

=head1 SYNOPSIS

 use strict;
 use warnings;
 use C::Blocks;
 use C::Blocks::PerlAPI; # for printf
 
 print "Before block\n";
 
 cblock {
     /* This is bare C code! */
     printf("From C block\n");
     int foo = 1;
     printf("foo = %d, which is %s\n", foo,
         (foo % 2 == 1 ? "odd (but not weird)" : "even"));
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
 
 # A function that sums all of the arguments
 csub csum {
     /* get "items" variable, and stack pointer
      * variables used by ST() */
     dXSARGS;
 
     int i;
     double sum = 0.;
     
     /* Sum the given numeric values. */
     for (i = 0; i < items; ++i) sum += SvNV( ST(i) );
     
     /* Prepare stack to receive return values. */
     XSprePUSH;
     /* Push the sum onto the return stack */
     mXPUSHn(sum);
     /* Indicate we're returning a single value
      * on the stack. */
     XSRETURN(1);
 }
 
 my $limit = shift || 5;
 my $return = csum(1 .. $limit);
 print "sum of 1 to $limit is $return\n";
 
 
 ### In file My/Fastlib.pm
 
 package My::Fastlib;
 use C::Blocks;
 use C::Blocks::PerlAPI;
 cshare {
     /* This function can be imported into other lexical scopes. */
     void say_hi() {
         printf("Hello from My::Fastlib\n");
     }
 }
 
 1;
 
 ### Back in your main Perl script
 
 # Pull say_hi into this scope
 use My::Fastlib;
 
 cblock {
     say_hi();
 }
 
 ### Use Perl to generate code at compile time
 
 # Create a preprocessor string with the full
 # path to our configuration file
 use File::HomeDir;
 use File::Spec;
 clex {
     #define CONF_FILE_NAME ${ '"' .
         File::Spec->catfile(File::HomeDir->my_home, 'myconf.txt')
          . '"' }
 }
 
 print "All done!\n"; 

=head1 ALPHA

This project is currently in alpha. The C<csub> keyword does not work
yet due to bewildering tcc-level symbol table lookup issues.

=head1 DESCRIPTION

Perl is great, but sometimes I find myself reaching for C to do some of 
my computational heavy lifting. There are many tools that help you 
interface Perl and C. This module differs from most others out there by 
providing a way of inserting your C code directly where you want it 
called, rather than hooking up a function to C code written elsewhere. 
This module was also designed from the outset with an emphasis on 
easily sharing C functions and data structures spread across various 
packages and source files. Most importantly, the C code you see in your 
script and your modules is the C code that gets executed when your run 
your script. It gets compiled by the extremely fast Tiny C Compiler 
I<at script parse time>.

C<C::Blocks> achieves all of this by providing new keywords that 
demarcate blocks of C code. There are essentially three types of 
blocks: those that indicate a procedural chunk of C code that should be 
run, those that declare C functions, variables, etc., that are used by 
other blocks, and those which produce XS functions that get hooked into 
the presently compiling package.

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

Code in C<cblock>s have access to declarations contained in any C<clex> 
or C<cshare> blocks that precede it. These blocks are discussed in the 
next section.

You can also use sigiled variable names in your C<cblock>s, and they 
will be mapped directly to the correct lexically scoped variables. 
(Bear in mind, though, that you will need to use L<C::Blocks::PerlAPI>. 
I plan to have this auto-load when it detects sigils, but it isn't 
smart enough yet.)

 use C::Blocks;
 use C::Blocks::PerlAPI;
 my $message = 'Greetings!';
 my @array;
 
 cblock {
     printf("The message variable contains: [%s]\n",
         SvPVbyte_nolen($message));
     sv_setnv($message, 5.938);
     av_push(@array, newSViv(7));
 }
 
 print "After the cblock, message is [$message]\n";
 print "and array contains @array\n";

This produces the output

 The message variable contains: [Greetings!]
 After the cblock, message is [5.938]
 and array contains 7

An important low-level detail is that the actual variable name for the 
SV*, AV*, or HV* in your C code is based on the original variable name 
with some gentle mangling. This lets you use C-side variables with the 
"same" name (sans the sigil):

 my $N = 100;
 my $result;
 cblock {
     int i;
     int result = 0;
     int N = SvIV($N); /* notice "same" name N */
     for (i = 1; i < N; i++) result += i;
     sv_setiv($result, result);
 }
 print "The brute-force sum from 1 to 100 is $result\n";
 print "Gauss would have said ", $N * ($N - 1) / 2, "\n";

=head2 Private C Declarations

A great deal of C's power lies in your ability to define compact data 
structures and reusable chunks of code. When you wish to declare such 
data structures or functions, use a C<clex> block. (If you wish to 
write a module full of functions and data structures for I<others> to 
use, you will use a C<cshare> block, which I'll explain shortly.) The 
declarations in such a block are available to any other C<cblock>s, 
C<clex>s, C<cshare>s, and C<csub>s that appaer later in the same 
lexical scope as the C<clex> block.

Such a block might look like this:

 use C::Blocks;
 use C::Blocks::PerlAPI;
 
 clex {
     typedef struct _point_t {
         double x;
         double y;
     } point;
     
     double point_distance_from_origin (point * loc) {
         /* Uncomment for debugging */
         // printf("x is %f, y is %f\n", loc->x, loc->y);
         return sqrt(loc->x * loc->x + loc->y * loc->y);
     }
     
     /* Assume they have an SV packed with a point struct */
     point * _point_from_SV(pTHX_ SV * point_SV) {
         return (point*)SvPV_nolen(point_SV);
     }
	 #define point_from_SV(point_sv) _point_from_SV(aTHX_ point_sv)
 }

Notice that I need to include C<PerlAPI> because I use structs and 
functions defined in the Perl C API (C<SV*> and C<SvPVbyte_nolen>). The
function C<sqrt> is defined in libmath, but that gets brought along
with the Perl API, so we don't need to explicitly include it.

Later in your file, you could make use of the functions in a C<cblock> 
such as:

 # Generate some synthetic data;
 my @pairs = map { rand() } 1 .. 10;
 # Uncomment for debugging:
 #print "Pairs are @pairs\n";
 
 # Assume pairs is ($x1, $y1, $x2, $y2, $x3, $y3, ...)
 # Create a C array of doubles, which is equivalent to an
 # array of points with half as many array elements
 my $points = pack 'd*', @pairs;
 
 # Calculate the average distance to the origin:
 my $avg_distance;
 cblock {
     point * points = point_from_SV($points);
     int N_points = av_len(@pairs) / 2 + 0.5;
     int i;
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

I mentioned that the symbol tables of C<clex> blocks are copied and a 
lexically scoped reference is made to the copy. The same is true of 
C<cshare> blocks, but a reference is also stored in the current 
package. Later, when somebody C<use>es the module (or otherwise calls 
the package's C<import> method in a C<BEGIN> block), the references to 
all C<cshare> symbol tables are copied into the caller's lexically 
scoped set of symbol tables.

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
injects a special C<import> method into the package that's being compiled. This
C<import> method properly copies the symbol table references in a lexically
scoped way so when some I<other> code C<use>s the pacage, the symbol tables are
available for use in C<cblock>s, etc.

If your module provides its own import method, or has package-scoped variables
such as C<our $import>, C::Blocks will issue a warning and refrain from injecting
the method.

If you module needs to provide its own import functionality, you can still get
the code sharing with something like this:

 no warnings 'C::Blocks::import';
 sub import {
  ... your code here
  C::Blocks::libloader::import(__PACKAGE__);
 }

This will perform the requisite magic to make the code from your
C<cshare> blocks visible to whichever packages C<use> your module, and
avoid the warning.

WARNING: At least for now, be sure to declare your C<import> method
I<before> any C<cshare> blocks in your package. Declaring them after a
C<cshare> block causes Perl to crash, probably because I'm not doing
something right.

=head2 XSUBs

Since the advent of Perl 5, the XS toolchain has made it possible to
write C functions that can be called directly by Perl code. Such
functions are referred to as XSUBs. C::Blocks provides similar
functionality via the C<csub> keyword. Just like Perl's C<sub> keyword,
this keyword takes the name of the function and a code block, and
produces a function in the current package with the given name.

Writing a functional XSUB requires knowing a fair bit about the Perl
argument stack and manipulation macros, so it will have to be discussed
at greater depth somewhere else. For now, it may be best to refer to
L<perlapi> and L<http://blog.booking.com/native-extensions-for-perl-without-smoke-and-mirrors.html>.

=head2 Generating C Code

Because C<C::Blocks> hooks on keywords, it is naturally invoked in
C<cblock>, C<cshare>, C<clex>, and C<csub> blocks which are themselves
contained within a string eval. However, string evals compile at
runtime, not script parse time. Although it would be easy to generate C
code using Perl, writing useful C<clex> and C<cshare> blocks is tricky.

For this reason, C<C::Blocks> provides a bit of notation for an
"interpolation block." An interpolation block is a block of Perl code
that is run as soon as it is extracted (i.e. during script compile time).
The return value is then inserted directly into the text that gets
compiled. Thus, these two C<cblock>s end up doing the same thing:

 cblock {
     printf("Hello!\n");
 }
 
 cblock {
     ${ 'printf' } ("Hello!\n");
 }

The example given in the L</SYNOPSIS> is probably more meaningful. It
also illustrates that the value returned by the Perl code has to be
literal C code, including the left and right double quotes for strings.
This arises because sigils (and interpolation blocks by extension, as
they are delimited by a sigil) are ignored within strings and C comments.

Note: The current implementation is unpolished. In particular, it does
not intelligently handle exceptions thrown during the evaluation of the
Perl code. (Indeed, at the moment it suppresses them.)

For the most part, any side effects from the code contained in
interpolation blocks behave exactly like side effects from BEGIN blocks.
There is an exception, however, for Perls earlier than 5.18. In these
older Perls, lexical variables become uninitialized after all interpolation
blocks execute, but before any BEGIN blocks run. This only applies to
lexically scoped variables, however. Changes to package-scoped variables
(including lexically scoped names, i.e. C<our $package_var>) persist,
as would be expected if these variables were set in BEGIN blocks.

=head2 Performance

C<C::Blocks> is currently implemented using the Tiny C Compiler, a 
compiler written to I<compile> fast, but not necessarily produce 
blazingly fast machine code. As such, the above code block is not going 
to run as quickly as the equivalent XS code compiled using C<gcc -O3>. 
What's more, Perl's core has been pretty highly optimized. 
Micro-optimizations that replace a handful of Perl statements with 
their C-API equivalents may give performance gains, but they are likely
to be incremental.

Where are you likely to see the most gains? The performance boost will 
be best when you have multiple tightly nested for-loops, where 
operations within the for loops are based on the indices. For example, 
you will see major improvements if you replace a naive prime number 
calculator written in Perl can be replaced with a prime number 
calculator written using C::Blocks.

To get the best performance, however, you should use C<C::Blocks> to 
write code that performs C operations on C structures. But then how do 
you declare your C data structures? And more importantly, how do you 
package those structures into a library in order to share those 
structures with others? That's what I discuss next.

=head2 Configuring the Compiler

Sometimes you need to configure the compiler. The most common situation
that arises involves linking against external libraries. You may also
need to include traditional compiler command-line arguments which you
obtain from the command-line, or from a configuration module. The
current means to do this is by setting special-purposed package
variables which get examined during the compilation stage.

NOTE: THIS API IS UNDER DEVELOPMENT. UNTIL C::BLOCKS REACHES v1.0, THIS
API IS SUBJECT TO CHANGE, LIKELY WITHOUT NOTICE.

To set most compiler settings, you simply treat
C<$C::Blocks::compiler_options> like the command-line. For example, if
you want to set preprocessor definition at runtime (but don't want to
use an interpolation block for some reason), you can use

 BEGIN { $C::Blocks::compiler_options = '-DDEBUG' }

A very important aspect to remember is that the compiler options, and
the shared libraries mentioned next, only apply to the first block they
encounter. The process of compiling a block clears these variables.

For C::Blocks, tcc does not handle linking to shared libraries, because
it does not know how to open shared libraries on Mac systems. Instead,
C::Blocks manages the shared libraries itself, loading libraries and
looking up symbols using Dynaloader. For this reason, the shared
libraries are not indicated with the typical C<-L> and C<-l> flags as
compiler options. Instead, each library should be added to the package
variable C<@C::Blocks::libraries_to_link>. Each string in this list
should be the full library name, including file extensions. If the
library is located in an unconventional location, the full path should
be specified.

=head2 Compiler and Linker Warnings

Compiler warnings (such as C<assignment from incompatible pointer type>)
and linker warnings (need example...) can be turned on and off using the
L<warnings> pragma with categories C<C::Blocks::compiler> and
C<C::Blocks::linker>. For example:

 use warnings;  # compiler and linker warnings ON
 ...
 no warnings 'C::Blocks::compiler';  # compiler warnings OFF
 ...
 use warnings 'C::Blocks::compiler';  # back ON

The warnings are handled using Perl's built-in warnings system, so as
with all warnings, the reporting of compiler and linker warnings can be
controlled lexically.

=head1 KEYWORDS

The way that C<C::Blocks> provides these functionalities is through lexically
scoped keywords: C<cblock>, C<clex>, C<cshare>, and C<csub>. These keywords
precede a block of C code encapsulated in curly brackets. Because these use the
Perl keyword API, they parse the C code during Perl's parse stage, so any code
errors in your C code will be caught during parse time, not during run time.

In addition to these keywords, C<C::Blocks> lets you indicate types and
type conversion with C<cisa>. Unlike the other keywords, this keyword is
not followed by a block of code, but the type and a list of variables.

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

Variables with C<$> sigils are interpreted as referring to the C<SV*>
representing the variable in the current lexical scope, unless otherwise
specified with a C<cisa> statement.

Note: If you need to leave a C<cblock> early, you should use a C<return>
statement without any arguments. This will also bypass the data repacking
provided by C<cisa> types.


=item clex { code }

C<clex> blocks contain function, variable, struct, enum, union, and 
preprocessor declarations that you want to use in other C<cblock>, 
C<clex>, C<cshare>, and C<csub> blocks that follow. It is important to 
note that these are strictly I<declarations> and I<definitions> that 
are compiled at Perl's compile time and shared with other blocks.

Sigil variables in C<clex> blocks are currently ignored.

=item cshare { code }

C<cshare> blocks are just like C<clex> blocks except that the 
declarations can be shared with other modules when they C<use> the 
current module.

=item csub name { code }

C code contained in a csub block is wrapped into an xsub function definition.
This means that after this code is compiled, it is accessible just like any
other xsub.

Currently, C<csub> does not work.

=item cisa type variable-list

If you include sigil variables in your C<cblock> blocks (not C<clex>,
C<cshare>, or C<csub>, just C<cblock>), they will normally be resolved
to the underlying SV data structure for that variable. Under many
circumstances, you do not need to manipulate the SV itself, but merely
need the data contained in the SV (or the object pointed to by the SV).
A C<cisa> statement tells C::Blocks that certain variables should be
represented by a C data structure other than an SV. The package used for
the type (must) have package constants that indicate the C type to use,
and how to marshall the data at the beginning and end of your block.

C<cisa> statements also have the runtime responsibility of validating
the data in the variables. Failed validations should probably throw
exceptions indicating which variables did not satisfy validation, and
why they failed. Your validation code can make as much or as little
noise as you deem appropriate, from quietly setting C<$@> to warning to
throwing exceptions. Note that you could include validation code in the
initialization function, but C<cisa> validation is only called once per
C<cisa> statement, whereas the variable initialization code is called
at the beginning of each C<cblock> that uses the variable.

Packages that represent types must include the package variables
C<$TYPE> and C<$INIT>. The first indicates the C type while the second
indicates a C macro or function that accepts an SV and returns the
data of type C<$TYPE>. C<$CLEANUP> is an optional macro or function that
takes the original SV and the (presumably revised) data, and updates the
contents of the SV. Runtime type checking is performed by the package
method C<check_var_types>, which gets key/value pairs of the variable
name and the variable.

=back

=head1 SEE ALSO

This module uses a special fork of the Tiny C Compiler. The fork is 
located at L<https://github.com/run4flat/tinycc>, and is distributed 
through the Alien package provided by L<Alien::TinyCCx>. To learn more 
about the Tiny C Compiler, see L<http://bellard.org/tcc/> and 
L<http://savannah.nongnu.org/projects/tinycc>. The fork is a major 
extension to the compiler that provides extended symbol table support.

For other ways of compiling C code in your Perl scripts, check out
L<Inline::C>, L<FFI::TinyCC>, L<C::TinyCompiler>, and L<XS::TCC>.

For mechanisms for calling C code from Perl, see L<FFI::Platypus> and
L<FFI::Raw>.

If you just want to mess with C struct data from Perl, see 
L<Convert::Binary::C>.

If you're just looking to write fast code with compact data structures, 
L<http://rperl.org/> may be just the ticket. It produces highly 
optmized code from a subset of the Perl language itself.

=head1 AUTHOR

David Mertens (dcmertens.perl@gmail.com)

=head1 BUGS

Please report any bugs or feature requests for the Alien bindings at 
the project's main github page: 
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
