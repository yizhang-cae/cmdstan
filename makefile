##
# CmdStan users: if you need to customize make options,
#   you should add variables to a new file called
#   make/local (no file extension)
#
# A typical option might be:
#   CXX = clang++
#
# Users should only need to set these variables:
# - CXX: The compiler to use. Expecting g++ or clang++.
# - O: Optimization level. Valid values are {s, 0, 1, 2, 3}.
#      Default is 3.
# - O_STANC: Optimization level for compiling stanc.
#      Valid values are {s, 0, 1, 2, 3}. Default is 0
# - STANCFLAGS: Extra options for calling stanc
# - AR: archiver (must specify for cross-compiling)
##

# The default target of this Makefile is...
help:

## Disable implicit rules.
.SUFFIXES:


##
# Library locations
##
STAN ?= stan/
MATH ?= $(STAN)lib/stan_math/

##########################
## FIXME(DL): Default compiler options broken in math tagged v2.18.0.
##            Once fixed, remove lines and replace with include
#-include $(MATH)make/default_compiler_options
O = 3
O_STANC = 0
AR = ar
CPPFLAGS = -DNO_FPRINTF_OUTPUT -pipe
# CXXFLAGS are just used for C++
CXXFLAGS = -Wall -I . -isystem $(EIGEN) -isystem $(BOOST) -isystem $(SUNDIALS)/include -std=c++1y -DBOOST_RESULT_OF_USE_TR1 -DBOOST_NO_DECLTYPE -DBOOST_DISABLE_ASSERTS -DBOOST_PHOENIX_NO_VARIADIC_EXPRESSION -Wno-unused-function -Wno-uninitialized
GTEST_CXXFLAGS = -DGTEST_USE_OWN_TR1_TUPLE
LDLIBS =
EXE =
WINE =


##########################


CXXFLAGS += -I src -isystem $(STAN)src -isystem $(MATH)
CXXFLAGS += -DFUSION_MAX_VECTOR_SIZE=12 -Wno-unused-local-typedefs
CXXFLAGS += -DEIGEN_NO_DEBUG
LDLIBS_STANC = -Lbin -lstanc
STANCFLAGS ?=
USER_HEADER ?= $(dir $<)user_header.hpp
PATH_SEPARATOR = /
CMDSTAN_VERSION := 2.18.0

-include $(HOME)/.config/cmdstan/make.local  # define local variables
-include make/local                       # overwrite local variables

-include $(MATH)make/libraries

##
# Get information about the compiler used.
# - CC_TYPE: {g++, clang++, mingw32-g++, other}
# - CC_MAJOR: major version of CC
# - CC_MINOR: minor version of CC
##
-include $(MATH)make/detect_cc

# OS_TYPE is set automatically by this script
##
# These includes should update the following variables
# based on the OS:
#   - CFLAGS
#   - GTEST_CXXFLAGS
#   - EXE
##
-include $(MATH)make/detect_os

-include $(MATH)make/setup_mpi
-include $(MATH)make/libstanmath_mpi # $(MATH)bin/libstanmath_mpi.a

WITH_EXTERN_PDE ?= 0
ifeq ($(WITH_EXTERN_PDE), 1)
	CXXFLAGS += -DSTAN_EXTERN_PDE -DSTAN_PDE_USER_HEADER="$(USER_HEADER)"
ifndef EXTERN_PDE_MAKEFILE
$(error EXTERN_PDE_MAKEFILE is not set)
endif
	include $(EXTERN_PDE_MAKEFILE)
endif


include make/libstan  # libstan.a
include make/models   # models
include make/tests
include make/command  # bin/stanc, bin/stansummary, bin/print, bin/diagnose
-include $(STAN)make/manual

##
# Tell make the default way to compile a .o file.
##
stan/%.o : stan/%.cpp
	$(COMPILE.cc) $< -O$O $(OUTPUT_OPTION) $(CXXFLAGS_MPI)

##
# Tell make the default way to compile a .o file.
##
%.o : %.cpp
	$(COMPILE.cc) $< -O$O -include $(dir $<)USER_HEADER.hpp  $(OUTPUT_OPTION) $(CXXFLAGS_MPI)

%$(EXE) : %.hpp %.stan $(LIBMPI)
	@echo ''
	@echo '--- Linking C++ model ---'
	@test -f $(dir $<)USER_HEADER.hpp || touch $(dir $<)USER_HEADER.hpp
	$(LINK.cc) $(CMDSTAN_MAIN) -O$O $(OUTPUT_OPTION) -include $< -include $(dir $<)USER_HEADER.hpp $(LIBSUNDIALS) $(CXXFLAGS_MPI) $(LIBMPI) $(LDFLAGS_MPI)

##
# Tell make the default way to compile a .o file.
##
bin/%.o : src/%.cpp
	@mkdir -p $(dir $@)
	$(COMPILE.cc) $< -O$O $(OUTPUT_OPTION)

##
# Tell make the default way to compile a .o file.
##
bin/stan/%.o : $(STAN)src/stan/%.cpp
	@mkdir -p $(dir $@)
	$(COMPILE.cc) $< -O$O $(OUTPUT_OPTION)

##
# Rule for generating dependencies.
# Applies to all *.cpp files in src.
# Test cpp files are handled slightly differently.
##
bin/%.d : src/%.cpp
	@if test -d $(dir $@); \
	then \
	(set -e; \
	rm -f $@; \
	$(COMPILE.cc) $< -O$O $(TARGET_ARCH) -MM > $@.$$$$; \
	sed -e 's,\($(notdir $*)\)\.o[ :]*,$(dir $@)\1.o $@ : ,g' < $@.$$$$ > $@; \
	rm -f $@.$$$$);\
	fi

%.d : %.cpp
	@if test -d $(dir $@); \
	then \
	(set -e; \
	rm -f $@; \
	$(COMPILE.cc) $< -O$O $(TARGET_ARCH) -MM > $@.$$$$; \
	sed -e 's,\($(notdir $*)\)\.o[ :]*,$(dir $@)\1.o $@ : ,g' < $@.$$$$ > $@; \
	rm -f $@.$$$$);\
	fi

.PHONY: help
help:	
	@echo '--------------------------------------------------------------------------------'
	@echo 'CmdStan v$(CMDSTAN_VERSION) help'
	@echo ''
	@echo '  Build CmdStan utilities:'
	@echo '    > make build'
	@echo ''
	@echo '    This target will:'
	@echo '    1. Build the Stan compiler bin/stanc$(EXE).'
	@echo '    2. Build the print utility bin/print$(EXE) (deprecated; will be removed in v3.0)'
	@echo '    3. Build the stansummary utility bin/stansummary$(EXE)'
	@echo '    4. Build the diagnose utility bin/diagnose$(EXE)'
	@echo ''
	@echo '    Note: to build using multiple cores, use the -j option to make. '
	@echo '    For 4 cores:'
	@echo '    > make build -j4'
	@echo ''
	@echo ''
	@echo '  Build a Stan program:'
	@echo ''
	@echo '    Given a Stan program at foo/bar.stan, build an executable by typing:'
	@echo '    > make foo/bar$(EXE)'
	@echo ''
	@echo '    This target will:'
	@echo '    1. Build the Stan compiler and the print utility if not built.'
	@echo '    2. Use the Stan compiler to generate C++ code, foo/bar.hpp.'
	@echo '    3. Compile the C++ code using $(CC) $(CC_MAJOR).$(CC_MINOR) to generate foo/bar$(EXE)'
	@echo ''
	@echo '  Additional make options:'
	@echo '    STANCFLAGS: defaults to "". These are extra options passed to bin/stanc$(EXE)'
	@echo '      when generating C++ code. If you want to allow undefined functions in the'
	@echo '      Stan program, either add this to make/local or the command line:'
	@echo '          STANCFLAGS = --allow_undefined'
	@echo '    USER_HEADER: when STANCFLAGS has --allow_undefined, this is the name of the'
	@echo '      header file that is included. This defaults to "user_header.hpp" in the'
	@echo '      directory of the Stan program.'
	@echo ''
	@echo ''
	@echo '  Example - bernoulli model: examples/bernoulli/bernoulli.stan'
	@echo ''
	@echo '    1. Build the model:'
	@echo '       > make examples/bernoulli/bernoulli$(EXE)'
	@echo '    2. Run the model:'
	@echo '       > examples'$(PATH_SEPARATOR)'bernoulli'$(PATH_SEPARATOR)'bernoulli$(EXE) sample data file=examples/bernoulli/bernoulli.data.R'
	@echo '    3. Look at the samples:'
	@echo '       > bin'$(PATH_SEPARATOR)'stansummary$(EXE) output.csv'
	@echo ''
	@echo ''
	@echo '  Clean CmdStan:'
	@echo ''
	@echo '    Remove the built CmdStan tools:'
	@echo '    > make clean-all'
	@echo ''
	@echo '--------------------------------------------------------------------------------'

.PHONY: help-dev
help-dev:
	@echo '--------------------------------------------------------------------------------'
	@echo 'CmdStan help for developers:'
	@echo '  Current configuration:'
	@echo '  - OS_TYPE (Operating System): ' $(OS_TYPE)
	@echo '  - CXX (Compiler):             ' $(CXX)
	@echo '  - Compiler version:           ' $(CC_MAJOR).$(CC_MINOR)
	@echo '  - O (Optimization Level):     ' $(O)
	@echo '  - O_STANC (Opt for stanc):    ' $(O_STANC)
ifdef TEMPLATE_DEPTH
	@echo '  - TEMPLATE_DEPTH:             ' $(TEMPLATE_DEPTH)
endif
	@echo '  Library configuration:'
	@echo '  - EIGEN                       ' $(EIGEN)
	@echo '  - BOOST                       ' $(BOOST)
	@echo '  - GTEST                       ' $(GTEST)
	@echo ''
	@echo '  If this copy of CmdStan has been cloned using git,'
	@echo '  before building CmdStan utilities the first time you need'
	@echo '  to initialize the Stan repository with:'
	@echo '     make stan-update'
	@echo ''
	@echo ''
	@echo 'Developer relevant targets:'
	@echo '  Stan management targets:'
	@echo '  - stan-update    : Initializes and updates the Stan repository'
	@echo '  - stan-update/*  : Updates the Stan repository to the specified'
	@echo '                     branch or commit hash.'
	@echo '  - stan-revert    : Reverts changes made to Stan library back to'
	@echo '                     what is in the repository.'
	@echo ''
	@echo 'Model related:'
	@echo '- bin/stanc$(EXE): Build the Stan compiler.'
	@echo '- bin/print$(EXE): Build the print utility. (deprecated)'
	@echo '- bin/stansummary$(EXE): Build the print utility.'
	@echo '- bin/diagnostic$(EXE): Build the diagnostic utility.'
	@echo '- bin/libstanc.a : Build the Stan compiler static library (used in linking'
	@echo '                   bin/stanc$(EXE))'
	@echo '- *$(EXE)        : If a Stan model exists at *.stan, this target will build'
	@echo '                   the Stan model as an executable.'
	@echo ''
	@echo 'Documentation:'
	@echo ' - manual:          Build the Stan manual and the CmdStan user guide.'
	@echo '--------------------------------------------------------------------------------'

.PHONY: build-mpi
build-mpi: $(LIBMPI)
	@echo ''
	@echo '--- boost mpi bindings built ---'

.PHONY: build
build: $(LIBMPI) bin/stanc$(EXE) bin/stansummary$(EXE) bin/print$(EXE) bin/diagnose$(EXE) $(LIBSUNDIALS)
	@echo ''
	@echo '--- CmdStan v$(CMDSTAN_VERSION) built ---'

##
# Clean up.
##
.PHONY: clean clean-manual clean-all

clean: clean-manual
	$(RM) -r test
	$(RM) $(wildcard $(patsubst %.stan,%.hpp,$(TEST_MODELS)))
	$(RM) $(wildcard $(patsubst %.stan,%$(EXE),$(TEST_MODELS)))

clean-manual:
	cd src/docs/cmdstan-guide; $(RM) *.brf *.aux *.bbl *.blg *.log *.toc *.pdf *.out *.idx *.ilg *.ind *.cb *.cb2 *.upa

clean-all: clean clean-libraries
	$(RM) -r bin
	$(RM) $(STAN)src/stan/model/model_header.hpp.gch

##
# Submodule related tasks
##

.PHONY: stan-update
stan-update :
	git submodule update --init --recursive

stan-update/%: stan-update
	cd stan && git fetch --all && git checkout $* && git pull

stan-pr/%: stan-update
	cd stan && git reset --hard origin/develop && git checkout $* && git checkout develop && git merge $* --ff --no-edit --strategy=ours

.PHONY: stan-revert
stan-revert:
	git submodule update --init --recursive


##
# Manual related
##
.PHONY: src/docs/cmdstan-guide/cmdstan-guide.tex
manual: src/docs/cmdstan-guide/cmdstan-guide.pdf
