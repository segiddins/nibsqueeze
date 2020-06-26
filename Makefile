
.PHONY: all clean

all: bin/nibsqueeze

CFLAGWARNINGS=-Werror -Wall -Weverything -pedantic -Wno-direct-ivar-access -Wno-padded -Wno-cstring-format-directive -Wno-objc-messaging-id -Wno-format-pedantic -Wno-format-pedantic -Wno-implicit-int-conversion

HEADERS = src/DeduplicateConstantObjects.h \
          src/DeduplicateValueInstances.h \
          src/MergeEqualObjects.h \
          src/MergeValues.h \
          src/MMMacros.h \
          src/MMNibArchive.h \
          src/MMNibArchiveClassName.h \
          src/MMNibArchiveObject.h \
          src/MMNibArchiveTypes.h \
          src/MMNibArchiveValue.h \
          src/SortNibContents.h \
          src/StripUnusedClassNames.h \
          src/StripUnusedValues.h

SOURCES = src/DeduplicateConstantObjects.m \
          src/DeduplicateValueInstances.m \
          src/main.m \
          src/MergeEqualObjects.m \
          src/MergeValues.m \
          src/MMNibArchive.m \
          src/MMNibArchiveClassName.m \
          src/MMNibArchiveObject.m \
          src/MMNibArchiveValue.m \
          src/SortNibContents.m \
          src/StripUnusedClassNames.m \
          src/StripUnusedValues.m

bin:
	mkdir -p bin

bin/nibsqueeze: bin Makefile $(HEADERS) $(SOURCES)
	$(CC) -o $@ -framework Foundation -fno-objc-arc -O0 $(CFLAGWARNINGS) $(CFLAGS) $(SOURCES)

clean:
	rm bin/nibsqueeze || true

