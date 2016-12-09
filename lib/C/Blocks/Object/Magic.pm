use strict;
use warnings;
package C::Blocks::Object::Magic;
{
	our $VERSION = '0.42';
	$VERSION = eval $VERSION;
	use C::Blocks;
	use C::Blocks::PerlAPI;

	cshare {
		STATIC MGVTBL null_mg_vtbl = {
			NULL, /* get */
			NULL, /* set */
			NULL, /* len */
			NULL, /* clear */
			NULL, /* free */
		#if MGf_COPY
			NULL, /* copy */
		#endif /* MGf_COPY */
		#if MGf_DUP
			NULL, /* dup */
		#endif /* MGf_DUP */
		#if MGf_LOCAL
			NULL, /* local */
		#endif /* MGf_LOCAL */
		};

		void xs_object_magic_attach_struct (pTHX_ SV *sv, void *ptr) {
			sv_magicext(sv, NULL, PERL_MAGIC_ext, &null_mg_vtbl, ptr, 0 );
		}

		SV *xs_object_magic_create (pTHX_ void *ptr, HV *stash) {
			HV *hv = newHV();
			SV *obj = newRV_noinc((SV *)hv);

			sv_bless(obj, stash);

			xs_object_magic_attach_struct(aTHX_ (SV *)hv, ptr);

			return obj;
		}

		STATIC MAGIC *xs_object_magic_get_mg (pTHX_ SV *sv) {
			MAGIC *mg;

			if (SvTYPE(sv) >= SVt_PVMG) {
				for (mg = SvMAGIC(sv); mg; mg = mg->mg_moremagic) {
					if (
						(mg->mg_type == PERL_MAGIC_ext)
							&&
						(mg->mg_virtual == &null_mg_vtbl)
					) {
						return mg;
					}
				}
			}

			return NULL;
		}

		void *xs_object_magic_get_struct (pTHX_ SV *sv) {
			MAGIC *mg = xs_object_magic_get_mg(aTHX_ sv);

			if ( mg )
				return mg->mg_ptr;
			else
				return NULL;
		}

		void *xs_object_magic_get_struct_rv_pretty (pTHX_ SV *sv, const char *name) {
			if ( sv && SvROK(sv) ) {
				MAGIC *mg = xs_object_magic_get_mg(aTHX_ SvRV(sv));

				if ( mg )
					return mg->mg_ptr;
				else
					croak("%s does not have a struct associated with it", name);
			} else {
				croak("%s is not a reference", name);
			}
		}

		void *xs_object_magic_get_struct_rv (pTHX_ SV *sv) {
			return xs_object_magic_get_struct_rv_pretty(aTHX_ sv, "argument");
		}
	}
}

1;

__END__

=head1 NAME

C::Blocks::Object::Magic - a C::Blocks version of XS::Object::Magic.

=head1 SYNOPSIS

  ######### In file My::Point #########
  
  use strict;
  use warnings;
  
  package mgpoint;
  {
    use C::Blocks;
    use C::Blocks::PerlAPI;
    use C::Blocks::Object::Magic;
    use Scalar::Util;
    use Carp qw(croak);
    
    cshare {
      /* Define a simple x/y data pint using a struct */
      typedef struct point {
        double x;
        double y; /* ;;; syntax hilite :-( */
      } point;
      
      /* C-side constructor allocates memory and initializes
       * the data to point to the origin. Note the macro
       * wrapper, which makes working with threaded perls a
       * little bit cleaner. */
      point * new_point(pTHX) {
        #define new_point() new_point(aTHX)
        point * to_return;
        Newx(to_return, 1, point);
        to_return->x = 0;
        to_return->y = 0;
        return to_return;
      }
      
      /* C-side function that retrieves and properly casts
       * the struct from the Perl-side SV. */
      point * data_from_SV(pTHX_ SV * perl_side) {
        #define data_from_SV(perl_side) data_from_SV(aTHX_ perl_side)
        return xs_object_magic_get_struct_rv(aTHX_ perl_side);
      }
    }
    
    # Perl-side constructor. Build an empty hash and attach the
    # point struct to it.
    sub new {
      my $class = shift;
      my $self = bless {}, $class;
      
      cblock {
        point * to_attach = new_point();
        xs_object_magic_attach_struct(aTHX_ SvRV($self), to_attach);
      }
      
      return $self;
    }
    
    # Perl-side accessor for setting the point's coordinate.
    sub set {
      my ($self, $x, $y) = @_;
      cblock {
        point * data = data_from_SV($self);
        data->x = SvNV($x);
        data->y = SvNV($y);
      }
    }
    
    # Perl-side method for computing the distance.
    sub distance {
      my $self = shift;
      my $to_return;
      cblock {
        point * data = data_from_SV($self);
        sv_setnv($to_return, sqrt(data->x*data->x + data->y*data->y));
      }
      return $to_return;
    }
    
    # Perl-side accessor/method with no counterpart in C
    # (illustrating that this really is a hashref-backed object).
    sub name {
      my $self = shift;
      return $self->{name} || 'no-name' if @_ == 0;
      $self->{name} = $_[0];
    }
    
    # Destructor should clean up the allocated struct memory.
    sub DESTROY {
      my $self = shift;
      cblock {
        Safefree(data_from_SV($self));
      }
    }
    
    # So this can be used as a cisa type
    our $TYPE = 'point *';
    our $INIT = 'data_from_SV';
    sub check_var_types {
      my $class = shift @_;
      my $message = '';
      while (@_) {
        my ($arg_name, $arg) = splice @_, 0, 2;
        $message .= "$arg_name is not defined\n" and next if not defined $arg;
        $message .= "$arg_name is not a reference\n" and next if not ref($arg);
        $message .= "$arg_name is not blessed\n" and next
          if not Scalar::Util::blessed($arg);
        $message .= "$arg_name is not a mgpoint\n" and next
          unless $arg->isa('mgpoint');
      }
      if ($message eq '') {
        undef $@;
        return 1;
      }
      chomp $message;
      croak($message);
    }
  }

  1;
  
  
  ######### In script using above My::Point #########
  use strict;
  use warnings;
  use My::Point;

  # Perl-side constructor and methods
  my $thing = My::Point->new;
  $thing->set(3, 4);
  print "Distance to ", $thing->name, " is ", $thing->distance, "\n";
  $thing->name('Random Point');

  # Access data from C-side...
  use C::Blocks;
  cblock {
    data_from_SV($thing)->x = 5;
  }
  # ... and illustrate that the modifications are Perl accessible
  print "After manual cblock, distance to ", $thing->name, " is ", $thing->distance, "\n";

  # Use cisa to make data manipulation code even cleaner
  cisa My::Point $thing;
  cblock {
    $thing->x = 7;
  }
  print "After cblock, distance to ", $thing->name, " is ", $thing->distance, "\n";

  # cisa validation won't let us use bad variables:
  my $foo = 8;
  cisa My::Point $foo; #BOOM! (a good boom here!)
  cblock {
    $foo->x = 7;
  }


=head1 DESCRIPTION

The module L<XS::Object::Magic> provides "opaque, extensible XS pointer
backed objects using C<sv_magic>". This module is a copy of the guts of
that module wrapped in C<cshare>, making it about as easy as possible
to opaquely attach pointers to Perl scalars using C::Blocks.

The synopsis given above has a number of comments discussing what is
going on. The synposis is not minimal, but instead points out a number
of tricks that can make C-backed objects easier to handle.

This module provides the following functions from L<XS::Object::Magic>:

=over

=item xs_object_magic_attach_struct

=item xs_object_magic_create

=item xs_object_magic_get_mg

=item xs_object_magic_get_struct

=item xs_object_magic_get_struct_rv_pretty

=item xs_object_magic_get_struct_rv

=back

Please consult L<XS::Object::Magic> for details on how these functions
operate.

=head1 TODO

I need to copy tests from XS::Object::Magic into this distribution's
test suite.

=head1 SEE ALSO

This module copies code verbatim from L<XS::Object::Magic>. Florian
Ragwitz deserves all the credit for coming up with the mechanism and
popularizing it with that module. This module simply tries to encourage
the practice by making it easy to do with C::Blocks.

Documentation that may be helpful include L<perlguts> and L<perlapi>.

And of course, the parent module for this project is L<C::Blocks>.

=head1 AUTHOR

Florian Ragwitz, Yuval Kogman

David Mertens (dcmertens.perl@gmail.com) is the author of C::Blocks and
prepared this wrapping of Florian's module.

=head1 BUGS

Please report any bugs or feature requests for this module at the
project's main github page:
L<http://github.com/run4flat/C-Blocks/issues>.

If you have found a bug with L<XS::Object::Magic>, I will pass it along
upstream.

=head1 ACKNOWLEDGEMENTS

As mentioned repeatedly, this module is primarily the work of others.
Thanks goes to Florian Ragwitz and Yuval Kogman, the authors of
L<XS::Object::Magic>.

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2009 Florian Ragwitz, Yuval Kogman, (c) 2016 David Mertens.
All rights reserved. This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

=cut
