/*----------------------------------------------------------------------
This source distribution is placed in the public domain by its author,
Ben Buhrow. You may use it for any purpose, free of charge,
without having to notify anyone. I disclaim any responsibility for any
errors.

Optionally, please be nice and tell me if you find this source to be
useful. Again optionally, if you add to the functionality present here
please consider making those additions public too, so that others may 
benefit from your work.	

Some parts of the code (and also this header), included in this 
distribution have been reused from other sources. In particular I 
have benefitted greatly from the work of Jason Papadopoulos's msieve @ 
www.boo.net/~jasonp, Scott Contini's mpqs implementation, and Tom St. 
Denis Tom's Fast Math library.  Many thanks to their kind donation of 
code to the public domain.
       				   --bbuhrow@gmail.com 11/24/09
----------------------------------------------------------------------*/

#include "qs_impl.h"
#include "ytools.h"
#include "common.h"
#include "tdiv_macros_common.h"
#include "tdiv_macros_32k.h"

//#define SIQSDEBUG 1

/*
We are given an array of bytes that has been sieved.  The basic trial 
division strategy is as follows:

1) Scan through the array and 'mark' locations that meet criteria 
indicating they may factor completely over the factor base.  

2) 'Filter' the marked locations by trial dividing by small primes
that we did not sieve.  These primes are all less than 256.  If after
removing small primes the location does not meet another set of criteria,
remove it from the 'marked' list (do not subject it to further trial
division).

3) Divide out primes from the factor base between 256 and 2^13 or 2^14, 
depending on the version (2^13 for 32k version, 2^14 for 64k).  

4) Resieve primes between 2^{13|14} and 2^16, max.  

5) Primes larger than 2^16 will have been bucket sieved.  Remove these
by scanning the buckets for sieve hits equal to the current block location.

6) If applicable/appropriate, factor a remaining composite with squfof

this file contains code implementing 4)


*/

void resieve_medprimes_32k(uint8_t parity, uint32_t poly_id, uint32_t bnum, 
						 static_conf_t *sconf, dynamic_conf_t *dconf)
{
	//we have flagged this sieve offset as likely to produce a relation
	//nothing left to do now but check and see.
	int i;
	uint32_t bound, report_num;
	int smooth_num;
	uint32_t *fb_offsets;
	sieve_fb_compressed *fbc;
	uint32_t block_loc;
	uint16_t *corrections = dconf->corrections;

	if (parity)
	{
		fbc = dconf->comp_sieve_n;
	}
	else
	{
		fbc = dconf->comp_sieve_p;
	}		

	for (report_num = 0; report_num < dconf->num_reports; report_num++)
	{

		if (!dconf->valid_Qs[report_num])
			continue;

		// pull the details of this report to get started.
		fb_offsets = &dconf->fb_offsets[report_num][0];
		smooth_num = dconf->smooth_num[report_num];
		block_loc = dconf->reports[report_num];
		
		// where tdiv_medprimes left off
		i = sconf->factor_base->fb_13bit_B;

		// the roots have already been advanced to the next block.
		// we need to correct them back to where they were before resieving.
		INIT_CORRECTIONS;


		bound = sconf->factor_base->fb_14bit_B;
		while ((uint32_t)i < bound)
		{
			uint32_t result = 0;

			RESIEVE_8X_14BIT_MAX;
			
			if (result == 0)
			{
				i += 8;
				continue;
			}

			CHECK_8_RESULTS;

			i += 8;
		}

		bound = sconf->factor_base->fb_15bit_B;
		while ((uint32_t)i < bound)
		{
			uint32_t result = 0;

			RESIEVE_8X_15BIT_MAX;
			
			if (result == 0)
			{
				i += 8;
				continue;
			}

			CHECK_8_RESULTS;

			i += 8;
		}

		bound = sconf->factor_base->med_B;
		while ((uint32_t)i < bound)
		{

			uint32_t result = 0;

			RESIEVE_8X_16BIT_MAX;
			
			if (result == 0)
			{
				i += 8;
				continue;
			}

			CHECK_8_RESULTS;

			i += 8;
		}

		// after either resieving or standard trial division, record
		// how many factors we've found so far.
		dconf->smooth_num[report_num] = smooth_num;	

	}

	return;
}
