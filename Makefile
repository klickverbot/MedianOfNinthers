# Definitions pertanining to the project

# $D is a directory for data that is generated but should not be discarded
# naively. $T is a temporary directory for object files, generated binaries, and
# intermediate results. $R is the directory where the final summary results are
# kept.
D = $(HOME)/data/median
ifeq ($(DRAFT),1)
R = results_draft
T = /tmp/MedianOfNinthers_draft
else
R = results
T = /tmp/MedianOfNinthers
endif
$(shell mkdir -p $D $R $T)

# Data sizes present in the paper
ifeq ($(DRAFT),1)
SIZES = 10000 31620 100000 316220 1000000 3162280
CFLAGS = -O4 -DCOUNT_SWAPS -DCOUNT_WASTED_SWAPS -DCOUNT_COMPARISONS
else
SIZES = 10000 31620 100000 316220 1000000 3162280
CFLAGS = -O4 -DNDEBUG
endif

# Utils
XPROD = $(foreach a,$1,$(foreach b,$3,$a$2$b))
XPROD3 = $(call XPROD,$1,$2,$(call XPROD,$3,$4,$5))

# Sources (without algos)
CXX_CODE = $(addprefix src/,main.cpp common.h timer.h)

# Algorithms
ALGOS = nth_element median_of_ninthers rnd3pivot ninther bfprt_baseline

# Data sets (synthetic)
SYNTHETIC_DATASETS = m3killer organpipe random random01 rotated sorted
# Benchmark files we're interested in
MK_OUTFILES = MEASUREMENTS_$1 = $(foreach n,$(SIZES),$(foreach a,$(ALGOS),$T/$1_$n_$a.out))
$(foreach d,$(SYNTHETIC_DATASETS),$(eval $(call MK_OUTFILES,$d)))

# Data sets (Google Books)
L = a b c d e f g h i j k l m n o p q r s t u v w x y z
GBOOKS_LANGS = eng fre ger ita rus spa
GBOOKS_CORPORA = $(foreach l,$(GBOOKS_LANGS),googlebooks-$l-all-1gram-20120701)

# All measurement output files
MEASUREMENT_OUTPUTS = $(foreach x,$(SYNTHETIC_DATASETS),$(MEASUREMENTS_$x)) \
  $(foreach x,$(call XPROD,$(ALGOS),_,$(GBOOKS_CORPORA)),$T/$x_freq.out)

# Results files will be included in the paper. Change this to affect what
# experiments are run.
RESULTS = $(addprefix $R/,$(SYNTHETIC_DATASETS) gbooks_freq)

###############################################################################

all: $(RESULTS)

clean:
	rm -rf $D/*.tmp $R*/* $T*/

pristine:
	rm -rf $D/ $R/* $T/

# Don't delete intermediary files
.SECONDARY:

################################################################################
# Data
################################################################################

.PHONY: data
data: $(foreach x,$(call XPROD,$(SYNTHETIC_DATASETS),_,$(SIZES)),$D/$x.dat) $(foreach c,$(GBOOKS_CORPORA),$D/$c_freq.dat)

$D/googlebooks-%_freq.dat: $D/googlebooks-%.txt
	cut -f 2 <$^ | rdmd -O -inline support/binarize.d >$@.tmp
	mv $@.tmp $@
$D/googlebooks-%.txt: $(foreach l,$L,$D/googlebooks-%-$l.gz)
	gunzip --stdout $^ | rdmd -O -inline support/aggregate_ngrams.d >$@.tmp
	mv $@.tmp $@
$D/googlebooks-%.gz:
	curl --fail http://storage.googleapis.com/books/ngrams/books/googlebooks-$*.gz >$@.tmp
	mv $@.tmp $@

define GENERATE_DATA
$D/$1_%.dat: support/generate.d
	rdmd -O -inline support/generate.d --kind=$1 --n=$$* >$$@.tmp
	mv $$@.tmp $$@
endef

$(foreach d,$(SYNTHETIC_DATASETS),$(eval $(call GENERATE_DATA,$d)))

################################################################################
# Measurements
################################################################################

.PHONY: measurements $(SYNTHETIC_DATASETS) $(GBOOKS_CORPORA)
measurements: $(SYNTHETIC_DATASETS) $(GBOOKS_CORPORA)

gbooks: $(foreach x,$(call XPROD,$(GBOOKS_CORPORA),_freq_,$(ALGOS)),$T/$x.out)

$(foreach d,$(SYNTHETIC_DATASETS),$(eval \
$d: $(MEASUREMENTS_$d);\
))

define MAKE_MEASUREMENT
$T/%_$1.out: $T/$1 $D/%.dat
	$$^ >$$@.tmp
	sed -n '/^milliseconds: /s/milliseconds: //p' $$@.tmp >$$@.tmp2
	mv $$@.tmp $$@.stats
	mv $$@.tmp2 $$@
$T/$1: src/$1.cpp $(CXX_CODE)
	$(CXX) $(CFLAGS) -std=c++14 -o $$@ $$(patsubst %.h,,$$^)
endef

$(foreach a,$(ALGOS),$(eval $(call MAKE_MEASUREMENT,$a)))

################################################################################
# Assemble measurement results
################################################################################

$R/gbooks_freq: gbooks
	echo "Corpus" $(foreach a,$(ALGOS), "  $a") >$@.tmp
	$(foreach l,$(GBOOKS_LANGS),echo -n "$l " >>$@.tmp && paste $(foreach a,$(ALGOS),$T/googlebooks-$l-all-1gram-20120701_freq_$a.out) >>$@.tmp &&) true
	mv $@.tmp $@

define MAKE_RESULT_FILE
$R/$1: $$(MEASUREMENTS_$1)
	echo $$^
	echo "Size" $$(foreach a,$$(ALGOS), "  $$a") >$$@.tmp
	$$(foreach n,$$(SIZES),echo -n "$$n\t" >>$$@.tmp && paste $$(foreach a,$$(ALGOS),$$T/$1_$$n_$$a.out) >>$$@.tmp &&) true
	mv $$@.tmp $$@
endef

$(foreach a,$(SYNTHETIC_DATASETS),$(eval $(call MAKE_RESULT_FILE,$a)))
