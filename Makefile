#
# Copyright (c) 2007, Cameron Rich
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the distribution.
# * Neither the name of the axTLS project nor the names of its
#   contributors may be used to endorse or promote products derived
#   from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR 
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
# TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY 
# OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

-include .config

############################################################################################
# common configure 
TOPDIR=$(CURDIR)
BUILD_DIR=build
CRYPTO_DIR=crypto
SSL_DIR=ssl
CONFIG_DIR=config

SAMPLE_C_DIR:=samples/c

# All executables and libraries go here
#ifneq ($(MAKECMDGOALS), clean)
-include .depend

CFLAGS += -Iconfig -Issl -Icrypto
LD=$(CC)
STRIP=$(CROSS)strip

 
CFLAGS += -Wall -Wstrict-prototypes -Wshadow
LDSHARED = -shared

ifndef CONFIG_PLATFORM_NOMMU
CFLAGS += -fPIC 
else
LDFLAGS += -enable-auto-import
endif

ifdef CONFIG_DEBUG
CFLAGS += -g
else
LDFLAGS += -s
CFLAGS += -O3
endif	# CONFIG_DEBUG


CFLAGS+=$(subst ",, $(strip $(CONFIG_EXTRA_CFLAGS_OPTIONS)))
LDFLAGS+=$(subst ",, $(strip $(CONFIG_EXTRA_LDFLAGS_OPTIONS)))

###########################################################################################
ifneq ($(strip $(HAVE_DOT_CONFIG)),y)
all: menuconfig
else
all: target
endif

target: $(BUILD_DIR) TARGET_LIBS SAMPLE_TARGET SSL_WRAP SSL_TEST_TARGET

# VERSION has to come from the command line
RELEASE=axTLS-$(VERSION)

############################################################################################
# build the ssl library
# 
BASETARGET=libaxtls.so
# shared library major/minor numbers
LIBMAJOR=$(BASETARGET).1
LIBMINOR=$(BASETARGET).1.2

TARGET_LIBS : $(BUILD_DIR)/libaxtls.a $(BUILD_DIR)/LIBMAJOR $(BUILD_DIR)/LIBMINOR

CRYPTO_SRC=$(wildcard $(CRYPTO_DIR)/*.c)
CRYPTO_OBJ=$(patsubst %.c, %.o, $(CRYPTO_SRC))

SSL_SRC=$(wildcard $(SSL_DIR)/*.c)
SSL_OBJ=$(patsubst %.c, %.o, $(SSL_SRC))

# do dependencies
-include .depend
.depend: $(wildcard $(SSL_DIR)/*.c  $(CRYPTO_DIR)/*.c)
	@$(CC) $(CFLAGS) -MM $^ > $@


$(BUILD_DIR)/libaxtls.a : $(CRYPTO_OBJ) $(SSL_OBJ)
	@$(AR) -r $@ $(CRYPTO_OBJ) $(SSL_OBJ)

$(BUILD_DIR)/LIBMAJOR $(BUILD_DIR)/LIBMINOR : $(CRYPTO_OBJ) $(SSL_OBJ)
	@$(LD) $(LDFLAGS) $(LDSHARED) -Wl,-soname,$(LIBMAJOR) \
	-o $(BUILD_DIR)/$(LIBMINOR) $(CRYPTO_OBJ) $(SSL_OBJ)
	@ln -sf $(TOPDIR)/$(BUILD_DIR)/$(LIBMINOR) $(BUILD_DIR)/$(LIBMAJOR)
	@ln -sf $(TOPDIR)/$(BUILD_DIR)/$(LIBMAJOR) $(BUILD_DIR)/$(BASETARGET)


LIBS_CLEAN:
	-@rm -f $(BUILD_DIR)/* *.a *.1 *.1.2
	-@rm -f $(SSL_DIR)/*.o

CLEANS+=$(LIBS_CLEAN)

###########################################################################################
# build the ssl test 
#
SSL_TEST_OBJ := $(SSL_DIR)/test/ssltest.o
SSL_PERFORMANCE_OBJ := $(SSL_DIR)/test/perf_bigint.o

ifdef CONFIG_PERFORMANCE_TESTING
$(BUILD_DIR)/perf_bigint: SSL_PERFORMANCE_OBJ $(BUILD_DIR)/libaxtls.a
	@$(LD) $(LDFLAGS) -o $@ $^ -L $(BUILD_DIR) -laxtls
else
$(BUILD_DIR)/perf_bigint:
endif

ifdef CONFIG_SSL_TEST
$(BUILD_DIR)/ssltest: $(SSL_TEST_OBJ) $(BUILD_DIR)/libaxtls.a
	@$(LD) $(LDFLAGS) -o $@ $^ -lpthread -L $(BUILD_DIR) -laxtls
else
$(BUILD_DIR)/ssltest:
endif

SSL_TEST_TARGET: $(BUILD_DIR)/ssltest $(BUILD_DIR)/perf_bigint

###########################################################################################
# build ssl wrap
#
WRAP_OBJ:=$(BUILD_DIR)/axtlswrap.o

ifdef CONFIG_HTTP_STATIC_BUILD
LIBS=$(BUILD_DIR)/libaxtls.a
else
LIBS=-L$(BUILD_DIR) -laxtls
endif

ifndef CONFIG_AXTLSWRAP
SSL_WRAP:
else
SSL_WRAP : $(WRAP_OBJ) $(BUILD_DIR)/libaxtls.a
	@$(LD) $(LDFLAGS) -o $@ $(WRAP_OBJ) $(LIBS)
ifdef CONFIG_STRIP_UNWANTED_SECTIONS
	@$(STRIP) --remove-section=.comment $(SSL_WRAP)
endif

endif   # CONFIG_AXTLSWRAP

###########################################################################################
# build httpd
#
ifdef CONFIG_HTTP_STATIC_BUILD
HTTPD_LIBS=$(BUILD_DIR)/libaxtls.a
else
HTTPD_LIBS=-L$(BUILD_DIR) -laxtls
endif


HTTPD_OBJ := axhttpd.o proc.o tdate_parse.o

HTTPD_OBJ:=$(HTTPD_OBJ:.o=.obj)
%.obj : %.c
	@$(CC) $(CFLAGS) $<

htpasswd.obj : httpd/htpasswd.c
	@$(CC) $(CFLAGS) $? 
	
HTTPD_TARGET1: $(HTTPD_OBJ)
	@$(LD) $(LDFLAGS) /out:$@ $(HTTPD_LIBS) $?

HTTPD_TARGET2: htpasswd.obj
	@$(LD) $(LDFLAGS) /out:$@ $(HTTPD_LIBS) $?

HTTPD_TARGET: HTTPD_TARGET1 HTTPD_TARGET2

###########################################################################################
# build sample  
#
SAMPLE_OBJ= $(SAMPLE_C_DIR)/axssl.o

ifdef CONFIG_C_SAMPLES
SAMPLE_TARGET: $(BUILD_DIR)/axssl

$(BUILD_DIR)/axssl: $(SAMPLE_OBJ) $(BUILD_DIR)/libaxtls.a
	@$(LD) $(LDFLAGS) -o $@ $(SAMPLE_OBJ) -L$(BUILD_DIR) -laxtls 
ifdef CONFIG_STRIP_UNWANTED_SECTIONS
	@$(STRIP) --remove-section=.comment $@
endif   # use strip
else
SAMPLE_TARGET:
endif    # CONFIG_C_SAMPLES


#############################################################################################
# # standard version
$(BUILD_DIR) : ssl/version.h
	@mkdir -p $(BUILD_DIR)

# create a version file with something in it.
ssl/version.h:
	@echo "#define AXTLS_VERSION    \"(no version)\"" > ssl/version.h
	       
doc:
	doxygen doc/axTLS.dox
	
test:
	cd $(BUILD_DIR); ssltest; ../ssl/test/test_axssl.sh; cd -;

# tidy up things
clean::
	-@rm -rf crypto/*.o
	-@rm -rf httpd/*.o
	-@rm -rf axtlswrap/*.o
	-@rm -rf samples/*.o
	-@rm -rf docsrc/*.o
	-@rm -rf ssl/*.o
	-@rm -rf $(BUILD_DIR)
	-@rm -fr docsrc/html *~


# ---------------------------------------------------------------------------
# mconf stuff
# ---------------------------------------------------------------------------

CONFIG_CONFIG_IN = Config.in
CONFIG_DEFCONFIG = defconfig

scripts/config/conf: scripts/config/Makefile
	@$(MAKE) -C scripts/config conf
	-@if [ ! -f .config ] ; then \
		cp $(CONFIG_DEFCONFIG) .config; \
	fi

scripts/config/mconf: scripts/config/Makefile
	@$(MAKE) -C scripts/config ncurses conf mconf
	-@if [ ! -f .config ] ; then \
		cp $(CONFIG_DEFCONFIG) .config; \
	fi

cleanconf:
	@$(MAKE) -C scripts/config clean
	@rm -f .config

menuconfig: scripts/config/mconf
	@$< $(CONFIG_CONFIG_IN)

config: scripts/config/conf
	@$< $(CONFIG_CONFIG_IN)

oldconfig: scripts/config/conf
	@$< -o $(CONFIG_CONFIG_IN)

default: scripts/config/conf
	@$< -d $(CONFIG_CONFIG_IN) > /dev/null
	@$(MAKE)

randconfig: scripts/config/conf
	@$< -r $(CONFIG_CONFIG_IN)

allnoconfig: scripts/config/conf
	@$< -n $(CONFIG_CONFIG_IN)

allyesconfig: scripts/config/conf
	@$< -y $(CONFIG_CONFIG_IN)
