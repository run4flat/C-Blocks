########################################################################
                       package C::Blocks;
########################################################################

use strict;
use warnings;
use warnings::register qw(import compiler linker type);

use Alien::TinyCCx;
use XSLoader;

# Use David Golden's version numbering suggestions. Note that we have to call
# the XSLoader before evaling the version string because XS modules check the
# version *string*, not the version *number*, at boot time.
our $VERSION = "0.42";
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

	# Enable keywords in lexical scope ("C::Blocks/keywords" isn't
	# a magical choice of hints hash entry, it just needs to match XS)
	$^H{"C::Blocks/keywords"} = 1;
	
	# Automatically import the PerlAPI, unless explicitly told otherwise
	unless (grep /-noPerlAPI/, @_) {
		require C::Blocks::PerlAPI;
		C::Blocks::load_lib('C::Blocks::PerlAPI')
	}
}

sub unimport {
	# and disable keywords!
	delete $^H{"C::Blocks/keywords"};
}


# Provided so I can call warnings::warnif from Blocks.xs. Why can't I
# just call warnings::warnif from that code directly????  XXX
sub warnif {
	my ($category, $message) = @_;
	warnings::warnif($category, $message);
}

# This function adds its module's symtab list (a series of pointers) to
# the calling lexical scope's hints hash. These symtabs are consulted
# during compilation of cblock declarations in the calling lexical
# scope. The keyword parser injects this function into module as its
# "import" sub if the module has one or more cshare blocks, and if the
# module does not already have an "import" sub.
sub C::Blocks::load_lib {
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
     /* These functions can be imported into other lexical scopes. */
     void say_hi() {
         printf("Hello from My::Fastlib\n");
     }
     void My::Fastlib::goodbye() {
         printf("Goodbye from My::Fastlib\n");
     }
 }
 
 1;
 
 ### Back in your main Perl script
 
 # Pull say_hi into this scope
 use My::Fastlib;
 
 cblock {
     say_hi();
     My::Fastlib::goodbye();
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

=head1 PRE-BETA

This project is currently in pre-beta. Is known to compile and pass its
test suite on a number of Windows, Linux, and Mac machines. Once the
test suite has been expanded, it will move to Beta, v0.50. For more on
goals and milestones, see the distribution's README.

=head1 DESCRIPTION

Neither C nor Perl is the perfect programming language. However, they 
are both very good, and between the two of them cover the vast majority 
of computational needs. Perl, of course, provides excellent string 
parsing and file management with a modern object and module system, all 
with a remarkably succinct and powerful syntax. C provides a crisp 
means for specifying and manipulating complex yet compact data 
structures and iterating over loops with minimal overhead. C::Blocks 
brings the strengths of these two languages together: it provide the 
easiest possible way to use the least amount of C for the greatest 
amount of impact in your Perl.

To use "the least amount of C" to accomplish a task, C::Blocks provides 
a new keyword, C<cblock>, which inserts your C code directly into the 
Perl OP tree precisely where you placed it. Because this block is 
placed directly in the context where it will execute, it makes sense to 
refer to lexical variables in the surrounding scope, something which is 
unfathomable for OPs written in separate XS files. This rich context 
makes it possible to use minimal C code to accomplish a great deal.

In order for C::Blocks to provide "the easiest possible way" to use C 
code, it provides a unique and Perlish mechanism for sharing symbol 
tables and linking functions from across multiple compilation units. In 
normal C you C<#include> the appropriate header files in order to 
manage your symbol table, and you link against the compiled shared 
object libraries. Of course, if you write a library with useful code, 
you also need to prepare those headers (keeping them synchronized as 
your codebase changes) and shared object files. With C::Blocks, you 
only need to focus on writing the useful code: the symbol tables are 
extracted from your code automatically; sharing occurs with C<use> 
statements; and linking occurs as-needed.

C::Blocks achieves "the greatest amount of impact" because it is built 
upon a custom extension of the Tiny C Compiler. This compiler is 
hand-written for fast compilation time, and so minimizes the script 
startup time. Furthermore, it can compile your C code to machine code 
without ever writing to disk, providing the efficiencies of compiled 
code without the cost of disk latency. The custom extension provides the
special symbol-table management already mentioned.

C<C::Blocks> achieves all of this by providing new keywords that 
demarcate blocks of C code and by providing mechanisms for marshalling 
your data between Perl and C. There are essentially three types of 
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
next section. By default, they also have access to the entire Perl C
API, and thus nearly all of the C standard library.

You can also use sigiled variable names in your C<cblock>s, and they 
will be mapped directly to the correct lexically scoped variables.

 use C::Blocks;
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

It often happens that the scalars you want to work with represent a
specific piece of information with a specific data type. In that case,
you do not want to manipulate the SV but instead want to work directly
with the data represented within the SV. If you indicate the type during
the variable's declaration, C::Blocks can use that type information to
automatically unpack and repack the data for you:

 # Need to pull in the type packages
 use C::Blocks::Types qw(double Int);
 my double $sum = 0;
 my Int $limit = 100;
 cblock {
     for (int i = 1; i < $limit; i++) {
         $sum += 1.0 / i;
	 }
 }
 print "The sum of 1/x for x from 1 to $limit is $sum\n";

The details for how types work, and how to create your own, are
discussed under L<C::Blocks/TYPES>.

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

(The function C<sqrt> is defined in libmath, which is included with the 
Perl API, which is loaded by default.) Later in your file, you could 
make use of the functions in a C<cblock> such as:

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

How does this work? First, the code in the C<clex> block gets compiled
down to machine code immediately after it is encountered. Second,
C::Blocks copies the C E<symbol table> for the code in the C<clex> and
stores a reference to it in a lexically scoped location. Later blocks
consult the symbol tables that are referenced in the current lexical
scope, and copy individual symbols on an as-needed basis into their own
symbol tables.

This code could be part of a module, but none of the C declarations would be
available to modules that C<use> this module. C<clex> blocks let you declare
private things to be used only within the lexical scope that encloses the
C<clex> block. If you want to share a C API, for others to use in their own
C<cblock>, C<clex>, C<cshare>, and C<csub> code, you should look into the next
type of block: C<cshare>.

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
available for use in C<cblock>s, etc. If your module provides its own import
method, or has package-scoped variables such as C<our $import>, C::Blocks will
issue a warning and refrain from injecting the method.

If your module needs to provide its own import functionality, you can still get
the code sharing with something like this:

 {
   no warnings 'C::Blocks::import', 'redefine';
   sub import {
     ... your code here
     C::Blocks::load_lib(__PACKAGE__);
   }
 }

This will perform the requisite magic to make the code from your
C<cshare> blocks visible to whichever packages C<use> your module, and
avoid the warning.

NOTE: You only need one of those two warnings. If you declare your
C<import> method before the first C<cshare> block then you should
disable C<C::Blocks::import> warnings. If you declare your C<import>
method after the first C<cshare> block, then you should disable warnings
on redefinitions.

WARNING: Declaring the C<import> method after the first C<cshare> block
used to cause segfaults. It seems to be OK now, but I'm not quite sure
why. Proceed with caution!

=head2 XSUBs

Since the advent of Perl 5, the XS toolchain has made it possible to
write C functions that can be called directly by Perl code. Such
functions are referred to as XSUBs. C::Blocks provides similar
functionality via the C<csub> keyword. Just like Perl's C<sub> keyword,
this keyword takes the name of the function and a code block, and
produces a function in the current package with the given name.

Writing a functional XSUB requires knowing a fair bit about the Perl
argument stack and manipulation macros, so it will have to be discussed
at greater depth somewhere else. For now, I hope the example in the
L</SYNOPSIS> is enough to get you started. For a more in-depth discussion, see
L<http://blog.booking.com/native-extensions-for-perl-without-smoke-and-mirrors.html>.
Once you've gotten through that, check out L<perlapi>.

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

=head2 Filtering C Code

In addition to generating raw C code, you can modify code before it is
compiled with a filter module. Filter modules are given the complete
contents of the code in the underbar variable C<$_> before it is
processed through the compiler. See L<C::Blocks::Filter> for more details.

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

=head2 Double-colons

Double colons are a standard notation for package-name resolution in
Perl. They are also invalid syntax in C. For this reason, C::Blocks lets
you use double-colons in your C code by performing a simple replacement.
Whenever C::Blocks encounters a double-colon that is not part of a
sigiled variable name or the contents of a string, it will replace the
pair with a pair of underscores. Thus this code:

 void My::Func() { ... }

actually gets compiled as

 void My__Func() { ... }

Note that this replacement does not modify the contents of strings, so
if you spit out a printed message such as

  printf("There was a problem in My::Module::method...\n");

the double-colons will pass through unscathed. In addition, this
replacement occurs with text provided by interpolation blocks and code
provided for type initialization and cleanup.

=head1 PERFORMANCE

C<C::Blocks> is not a silver bullet for performance. Other Perl 
libraries more tailored to your goal may serve you better. Sometimes 
they will lead to fewer lines of code, or clearer code, than the 
corresponding C code. Other times they will be built on solid libraries 
which are blazing fast already. C<C::Blocks> is implemented using the 
Tiny C Compiler, a compiler that I<compiles> fast and produces machine 
code, but which is of mediocre quality. If you compiled the exact same 
code with a high-quality compiler such as C<gcc -O3>, it would take 
longer to compile, but the resulting machine code would be more 
efficient. When can you expect a C::Blocks solution to be a good 
choice?

=head2 When not to use C::Blocks

Don't rewrite an existing XS module using C::Blocks. A C::Blocks API to 
your XS code might be useful, but don't rewrite mature XS code. 
C::Blocks can save you from the effort of producing a new XS 
distribution, but if you've already put in that effort, don't throw it 
away.

Don't replace a handful of Perl statements with their C-API 
equivalents. Perl's core has been pretty highly optimized and is 
compiled at high optimization levels. At best, you'll get incremental
performance gains, and they will likely come at the expense of many
additional lines of code. This probably isn't worth it.

Don't discount the cost of marshalling Perl data into C data. Obtaining 
C representations of your data will always cost you at least a few 
clock cycles, and it will usually add lines of code, too. You're likely 
to see the best performance benefits if you can marshall the data as 
early as possible and use that C-accessible data many times over. For 
example, if you have a data-parsing stage in which you build a complex 
data structure representing that data, try to build a C structure 
instead of a Perl structure at parse time. All future operations will
have access to the C representation.

=head2 C::Blocks vs Perl and PDL

In what follows, I assume you have already marshalled your data into a
C data structure, like an array or a struct.

C<C::Blocks> outperforms Perl on O(N) numeric calculations on arrays, 
often by a factor greater than 10. (An O(N) calculation is any 
algorithm that only needs to examine each data point once, so the 
calculation should scale with the number of data points.) In fact, 
C<C::Blocks> is competitive with L<PDL> in such calculations. 
C<C::Blocks> requires more lines of code, though. For a calculation of 
the average of a dataset, L<PDL> uses only one line, a Perl 
implementation uses three, and C::Blocks uses 14. What you gain in 
speed you lose in lines of code.

Another interesting comparison between L<PDL> and C::Blocks is the 
calculation of euclidian distance for an N-dimensional vector, where N 
scales from very small to very large numbers. The calculation is always 
O(N), but is more complex than the simple average already discussed, 
and not explicitly implemented as a low-level L<PDL> routine. The 
L<PDL> implementation is only a single very readable line, highlighting 
L<PDL>'s expresiveness. The C::Blocks implementation is 14 lines of 
traditional C code, making it straight-forward but lengthy. The 
C::Blocks has the upper hand in execution rate---always faster than 
L<PDL>, though never more than by a factor of two---and in predictable 
scaling---almost perfectly linear in system size, vs slightly nonlinear 
behavior in the PDL implementation. I'd say the number of lines of code
is the primary deciding factor here, but the trade-off might fall
differently for more complicated calculations.

The calculation of the Mandelbrot set provides a very interesting 
benchmark. The algorithm involves a loop that has a fixed maximun 
number of iterations, but which can exit early if the calculation 
converges. This exit-early algorithm knocks PDL out of the race. 
There's no good way to implement this in PDL short of writing a 
low-level implementation.

The comparsion between C::Blocks and PDL can best be summarized thus. 
If you have a very small dataset, less than 1000 elements, C::Blocks 
will out-perform PDL due to PDL's costly method launch mechanism. If 
you have multiple tightly nested for-loops, where operations within the 
for loops are based on the indices, then C::Blocks will likely give you 
a competitive computation rate, at the cost of many more lines of code. 
If those for-loops have the possibility of an early exit, PDL may run 
significantly slower than C::Blocks, and may even run slower than pure 
Perl. Finally, if you have image manipulations or calculations, PDL is 
almost certainly the better tool, as it has a lot of low-level image 
manipulation routines already.

=head2 C::Blocks vs Graph

I have not had the opportunity to write and run additional benchmarks 
for C::Blocks. The next obvious choice would be a comparison with
L<Graph>, but I have not yet endeavored to produce those calculations.

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

By default, variables with C<$> sigils are interpreted as referring to
the C<SV*> representing the variable in the current lexical scope. The
exception is when a variable is declared with a type, a la

 my Class::Name $thing;

Here C<Class::Name> specifies the type of C<$thing>. The package
C<Class::Name> has information used by C::Blocks to unpack and repack
C<$thing> into the appropriate C data type. Implementation details are
discussed under L<C::Blocks/TYPES>.

Note: If you need to leave a C<cblock> early, you should use a C<return>
statement without any arguments. In particular, this will bypass any
cleanup code provided by types.

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

=back

=head1 TYPES

Perl lets you declare the type of a lexically scoped variable with
syntax like this:

 my Some::Class $foo;

Here, Perl knows that C<$foo> is of type C<Some::Class>. However, it
does not let C<Some::Class> do much with C<$foo>, rendering this feature
mostly useless. It is useful for C::Blocks, however, because C::Blocks
I<can> use the type of a scalar: it consults that package for
information about how to unpack and repack C<$foo> into a more useful
C-side data type.

Type classes for basic C data types (like C<double> and C<long>) are
provided in L<C::Blocks::Types>. In this section, I discuss how you
might create your own type class that can be utilized by C::Blocks.

When a type-annotated sigiled variable is used in a C<cblock>, 
C::Blocks looks for a function C<c_blocks_init_cleanup> in the type 
package and calls it. This class method is expected to produce 
initialization code for the variable, and optionally to produce cleanup 
code as well. This code is added to the beginning and end of the larger 
chunk of C code that eventually gets compiled.

To understand how all of this works, let's examine what C::Blocks does 
when we do not specify a type for our scalar. Here is a way to 
manipulate the floating-point value of a Perl variable using C::Blocks:

 my $foo;
 cblock {
     sv_setnv($foo, 3.14159);
 }

The actual C code that gets produced for the C<cblock> is a void
function that looks essentially like this:

 void op_func() {
     SV * _PERL_SCALAR_foo = (SV*)PAD_SV(3);
     sv_setnv(_PERL_SCALAR_foo, 3.14159);
 }

In the first line of this function, the SV associated with C<$foo> is 
retrieved from the current PAD. The next line is exactly what we typed 
in the C<cblock>, except that C<$foo> has been replaced with 
C<_PERL_SCALAR_foo>.

When we use types, we can say what we mean more directly:

 use C::Blocks::Types;
 my C::Blocks::Type::double $foo = 0;
 cblock {
     $foo = 3.14159;
 }

Indented for clarity, the actual code that gets produced for the 
C<cblock> this looks like:

 void op_func() {
     SV * SV__PERL_SCALAR_foo = (SV*)PAD_SV(3);
     double _PERL_SCALAR_foo
         = SvNV(SV__PERL_SCALAR_foo);
     
     _PERL_SCALAR_foo = 3.14159;
     
     sv_setnv(SV__PERL_SCALAR_foo,
         _PERL_SCALAR_foo);
 }

The midddle line of code, C<_PERL_SCALAR_foo = 3.14159>, clearly
comes from the contents of the C<cblock>. The rest was supplied by the
C<c_blocks_init_cleanup> method of the C<C::Blocks::Type::double>
package. This example illustrates what this method is supposed to do.

The C<c_blocks_init_cleanup> method is supposed to return a string with
initialization code and, optionally, another string containing cleanup
code. In order to construct that code, the method is called with the
following arguments:

=over

=item package name

The type's package name. In this case it would be
C<C::Blocks::Type::double>.

=item C variable name

The long-winded semi-mangled variable name. In this case, for the 
variable C<$foo>, we got the name C<_PERL_SCALAR_foo>. This 
string of characters is injected into the cblock wherever it encounters 
C<$foo>, so the code must declare a variable with this name.

=item sigil type

The C struct type for this associated sigil. If the sigil is C<$>, we'll
get C<SV>, for C<@>, we'll get C<AV>, and for C<%>, we'll get C<HV>.

=item pad offset

The integer offset of the variable in the current pad.

=back

The method must use this information to produce a string containing 
initialization code. In this example, the generated code is a sequence 
of C declarations that culminate in C<_PERL_SCALAR_foo> being a 
variable of type C<double> and being assigned the current 
floating-point value of the Perl variable C<$foo>. It also produces a 
string containing "cleanup" code, code that modifies C<$foo> with the 
value of C<_PERL_SCALAR_foo> as the block comes to a close.

If your type only needs to unpack a value, and does not need to perform
any cleanup, then a rudimentary template for C<c_blocks_init_cleanup>
could look like this:

 sub c_blocks_init_cleanup {
     my ($package, $C_name, $sigil_type, $pad_offset) = @_;
     
     # Should probably die if $sigil_type is not SV
     # but I can't handle that quite yet. :-(
     
     # Assumes that some_type and get_some_type_from_SV
     # have been defined in some clex or cshare block:
     return qq{
         some_type * $C_name
             = get_some_type_from_SV(PAD_SV($pad_offset));
     };
 }

The most critical pieces are that C<PAD_SV($pad_offset)> must be used to
retrieve the SV, and we must interpolate the C<$C_name> as the name of
the C-side variable.

If some part of the initialization process allocates resources that need
to be cleaned up when the block comes to a close, that code should be
returned as the second return value of the method:

 sub c_blocks_init_cleanup {
     my ($package, $C_name, $sigil_type, $pad_offset) = @_;
     
     # Should probably die if $sigil_type is not SV
     # but I can't handle that quite yet. :-(
     
     # Assumes that some_type and get_some_type_from_SV
     # have been defined in some clex or cshare block:
     my $init_code = qq{
         FILE *fp_$C_name = fopen("logfile_$C_name", "a");
         some_type * $C_name
             = get_some_type_from_SV(PAD_SV($pad_offset));
     };
     my $cleanup_code = qq{
	     fclose(fp_$C_name);
	 }
	 return ($init_code, $cleanup_code);
 }

In this case, the user would not only have access to their variable as
the provided C type, but they would have an additional file handle that
they could use for logging. A C<cblock> using this would be able to say

 my Some::Type $foo;
 cblock {
     fprintf(fp_$foo, "about to call big-operation\n");
     
     big_operation($foo, 5, "hello");
     
     fprintf(fp_$foo, "Finished big-operation\n");
 }

Of course, this example is a bit contrived: you should probably handle
this sort of logging at the Perl level. However, it gives you some idea
for how you could use cleanup code together with initialization code.

(Eventually include a full example of a class that wraps itself around
a C struct, including all necessary cshare statements, so that the
init code's call to special functions make sense.)

=head1 TROUBLESHOOTING

The simplest answer to troubleshooting, of course, is to cut out
potentially offending segments of code and to sprinkle in print
statements. However, certain errors warrant more specific advice:

=head2 Null pointer for op function

The following error is one of the most irksome:

 C::Blocks internal error: got null pointer for op function!

It gives no advice for how what tripped the problem, mostly because by
the time this error is tripped the compiler can't say what went wrong.
I believe this can be triggered in a handful of circumstances, including

=over

=item attempting to use a statically scoped variable

C::Blocks automatically removes the "static" marker on functions, but
not on global variables. A global variable marked as static is known to
the compiler but is not to be accessible outside the compilation unit.
Because it is known, the compiler does not issue any warnings or errors
about unknown identifiers; but because it is static, the compiler does
not link to it, and so the relocation step of compilation fails.

=back

=head2 Segmentation Fault

There seem to be ways in which you can trigger a segmentation fault with
valid C code. It is likely that there are many such paths, but the known
paths include:

=over

=item definition of a function called "new"

For reasons that are not clear to me, defining a function called "new"
without a preceding declaration blows things up. Oddly, if you declare
the function first, then define it, there are no apparent problems. This
seems likely to be a bug in TCC, but more investigations are needed
before I can say anything definitive.

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
