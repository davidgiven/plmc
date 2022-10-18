CXX = g++
LLVM_CONFIG = llvm-config

CXXFLAGS = -Os -g \
	-I src \
	-I $(OBJDIR)/src \
	-I $(shell $(LLVM_CONFIG) --includedir) \

LDFLAGS = \
	-lfmt \
	$(shell $(LLVM_CONFIG) --libs) \

OBJDIR = .obj

SRCS = \
	src/main.cc \
	src/parsecontext.cc \

OBJS := $(patsubst %.cc, $(OBJDIR)/%.o, $(SRCS)) \
	$(OBJDIR)/src/parser.tab.o \
	$(OBJDIR)/src/lexer.lex.o \

plmc: $(OBJS)
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LDFLAGS)

$(OBJDIR)/%.o: %.cc
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) -MT $@ -MMD -MP -MF $(patsubst %.o,%.d,$@) -c -o $@ $<

$(OBJDIR)/%.o: $(OBJDIR)/%.cc
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) -MT $@ -MMD -MP -MF $(patsubst %.o,%.d,$@) -c -o $@ $<

$(OBJDIR)/%.tab.cc $(OBJDIR)/%.tab.h: %.y
	@mkdir -p $(dir $@)
	bison --header=$(OBJDIR)/$*.tab.h --output=$(OBJDIR)/$*.tab.cc --language=c++ $<

$(OBJDIR)/%.lex.cc $(OBJDIR)/%.lex.h: %.l
	@mkdir -p $(dir $@)
	flex --header-file=$(OBJDIR)/$*.lex.h --outfile=$(OBJDIR)/$*.lex.cc $<

clean:
	rm -rf $(OBJDIR) plmc

src/main.cc: $(OBJDIR)/src/parser.tab.h
src/parsecontext.cc: $(OBJDIR)/src/parser.tab.h
$(OBJDIR)/src/parser.tab.cc: $(OBJDIR)/src/lexer.lex.h
#$(OBJDIR)/src/lexer.lex.cc: $(OBJDIR)/src/parser.tab.h

-include $(patsubst %.o,%.d,$(OBJS))

.SECONDARY:
.DELETE_ON_ERROR:

