CXX = g++

CXXFLAGS = -Os -g \
	-I src \
	-I $(OBJDIR)/src \

LDFLAGS = \
	-lfmt

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

$(OBJDIR)/src/parser.tab.cc: $(OBJDIR)/src/lexer.lex.h

-include $(patsubst %.o,%.d,$(OBJS))

.SECONDARY:
.DELETE_ON_ERROR:

