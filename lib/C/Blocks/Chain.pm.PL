use strict;
use warnings;

# Pull in what we need for both the .h file and the C::Blocks library from
# the __DATA__ filehandle

my $header_filename = 'chain.h';

use Module::Build;
my $build = Module::Build->current;
$build->add_to_cleanup($header_filename);
open my $out_fh, '>', $header_filename;

# Collect the header contents into a string that we can later copy into the
# Perl module file.
my $header_contents = '';

while(my $line = <DATA>) {
	last if $line =~ /-- Perl --/;
	$header_contents .= $line;
	print $out_fh $line;
}
close $out_fh;
open $out_fh, '>', $ARGV[0];
while(my $line = <DATA>) {
	if ($line =~ /-- insert header --/) {
		print $out_fh $header_contents;
	}
	else {
		print $out_fh $line;
	}
}
close $out_fh;

__DATA__

/* Layout and terminology
 *
 * header of the link
 *  |
 *  v
 * |xxxxxxxx|xxxxxxxx|xxxxxx...
 *     ^         ^    \_______/
 *     |         |        |
 *    prev      next     item
 *  \_______________/
 *          |
 *         link
 *
 * The user carries around pointers to the item, but the pointers to the head
 * of the previous and next link can be found just behind the pointer to the
 * item. This whole system works best when the item is a struct. Otherwise,
 * dereferencing can get rather confusing.
 */

#define chain_new(type) (type*)(2*sizeof(void*) + mallocz(2*sizeof(void*) + sizeof(type)))

#define chain_new_after(linked_item, type) (type*)_chain_new_after(linked_item, sizeof(type))
void * _chain_new_after(void * linked_item, int type_n_bytes) {
	void ** curr_header = (void**)(linked_item - 2);
	void * next = curr_header[1];
	void ** new_header = (void**)mallocz(2*sizeof(void*) + type_n_bytes);
	curr_header[1] = (void*)new_header;
	new_header[0] = (void*)curr_header;
	new_header[1] = next;
	return new_header[2];
}
#define chain_insert_after(curr_item, to_insert) (_chain_insert_after(curr_item, to_insert), to_insert)
void _chain_insert_after(void * curr_item, void * new_item) {
	void ** curr_header = (void**)(curr_item - 2);
	void ** new_header  = (void**)(new_item - 2);
	
	/* If this linked list element is in the middle of a linked list, cut the
	 * parent linked list at this point. */
	if (new_header[0] != NULL) ((void**)new_header[0])[1] = NULL;
	
	void * to_append_at_end = curr_header[1];
	curr_header[1] = (void*)new_header;
	new_header[0] = (void*)curr_header;
	
	/* Go to the end of new_header's list and connect that end point with the rest
	 * of this list. */
	while(new_header[1] != NULL) new_header = (void**)new_header[1];
	new_header[1] = to_append_at_end;
	(void**)to_append_at_end[0] = (void*)new_header;
}
void chain_free(void * linked_item) {
	void ** curr_header = (void**)(linked_item - 2);
	
	/* Find the first item in the list */
	while(curr_header[0] != NULL) curr_header = (void**)(curr_header[0]);
	
	void * next;
	while(curr_header) {
		next = curr_header[1];
		free(curr_header);
		curr_header = (void**)next;
	}
}

#define chain_to_next(item) (item = (void**)item[-1], item)
#define chain_to_prev(item) (item = (void**)item[-2], item)

-- Perl --

use strict;
use warnings;

package C::Blocks::SimpleLinkedList;

use C::Blocks;

cshare {
	-- insert header --
}

1;

=head1 NAME

C::Blocks::Chain - simple implementation of a generic linked list container

=head1 SYNOPSIS

 use strict;
 use warnings;
 use C::Blocks;
 cuse C::Blocks::Chain;
 
 cblock {
     /* Define the data structure */
     typedef struct _my_cat {
         int age;
         char * name;
     } my_cat;
     
     /* Allocate the first cat of the chain */
     my_cat * first_cat = chain_new(my_cat);
     first_cat->age = 9;
     first_cat->name = "Binx";
     
     /* Allocate the second element of the linked list */
     my_cat * second_cat = chain_new_after(first_cat, my_cat);
     second_cat->age = 8;
     second_cat->name = "Ditto";
     
     my_cat * curr_cat = first_cat;
     while(chain_to_next(curr_cat)) {
         printf("Cat named %s is %d years old\n", curr_cat->name, curr_cat->age);
     }
     
     /* I can free from any point in the chain, and the whole chain will be
      * cleaned up. */
     chain_free(second_cat);
 }

=head1 DESCRIPTION

This C::Blocks module provides a simple struct-agnostic implementation of
linked lists. It's not meant to be the best possible implementation of linked
lists, and so it is called C<Chain>, not C<LinkedList>. A better coder than me
will hopefully make use of that module name.

=cut
