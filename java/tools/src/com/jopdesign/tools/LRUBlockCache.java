
/**
*
*	Simulation of simple cache (as in JOP)
*
*/

package com.jopdesign.tools;

public class LRUBlockCache extends Cache {

	int[] ctag;
//	int[] clen;		// for different replace policy
	int[] lrucnt;

//	int[] addr = {0, 0};
	int next = 0;
//	int currentBlock = 0;
	int numBlocks;

	LRUBlockCache(int[] main, JopSim js, int cnt) {

		mem = main;
		sim = js;
		numBlocks = cnt;
		bc = new byte[MAX_BC*numBlocks];
		ctag = new int[numBlocks];
		lrucnt = new int[numBlocks];
		for (int i=0; i<numBlocks; ++i) {
			ctag[i] = -1;
			lrucnt[i] = 0;
		}
	}


	int corrPc(int pc) {

		// save block relative pc on invoke
		return pc & (MAX_BC_MASK);
	}

	int invoke(int start, int len) {

		int off = testCache(start, len);
		return off;
	}

	int ret(int start, int len, int pc) {

		int off = testCache(start, len);
		return off+pc;
	}

	int testCache(int start, int len) {

		for (int i=0; i<numBlocks; ++i) {
			if (ctag[i]==start) {	// HIT
				lrucnt[i]++;
				return i*MAX_BC;
			}
		}

		// not found

//
//	LRU system
//
		int min = lrucnt[0];		// finde last recently used block
		int max = lrucnt[0];		// and max lru count
		int usenr = 0;
		for (int i=1; i<numBlocks; ++i) {
			if (lrucnt[i] < min) {
				min = lrucnt[i];
				usenr = i;
			} else if (lrucnt[i] > max) {
				max = lrucnt[i];
			}
		}

//for (int i=0; i<4; ++i) System.out.print(lrucnt[i]+" "); System.out.println("\t\tnew usenr="+usenr);
//
//	discard smallest
//
/* not really good!!!
		int small = clen[0];
		usenr = 0;
		for (int i=1; i<4; ++i) {
			if (clen[i] < small) {
				small = clen[i];
				usenr = i;
			}
		}
for (int i=0; i<4; ++i) System.out.print(clen[i]+" "); System.out.println(" new usenr="+usenr);
*/

		ctag[usenr] = start;		// use block usenr
		lrucnt[usenr] = max+1;
//		clen[usenr] = len;


		for (int i=0; i<numBlocks; ++i) {	// bring lru counters back to low value
			lrucnt[i] -= min;
		}
		int off = usenr*MAX_BC;

		loadBc(off, start, len);
		return off;
	}

	void loadBc(int off, int start, int len) {

// high byte of word is first bc!!!
		for (int i=0; i<len; ++i) {
			int val = sim.readInstrMem(start+i);
			for (int j=0; j<4; ++j) {
				bc[off+i*4+(3-j)] = (byte) val;
				val >>>= 8;
			}
		}

		memRead += len*4;
		memTrans++;
	}

	byte bc(int addr) {

		++cacheRead;
		return bc[addr];
	}


	public String toString() {

		return super.toString()+" ("+numBlocks+" blocks)";
	}
}
