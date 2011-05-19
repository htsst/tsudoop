PROGRAM=wordcount
SRCS=wordcount.cpp
OBJS=wordcount.o

HADOOP_HOME=/work0/GSIC/apps/tsudoop/apps/hadoop-0.21.0

CC := g++
RM := rm


CPPFLAGS=-I$(HADOOP_HOME)/c++/Linux-amd64-64/include
LDFLAGS=-L$(HADOOP_HOME)/c++/Linux-amd64-64/lib -lhadooppipes -lhadooputils -lpthread

wordcount: wordcount.cpp
	$(CC) $(CPPFLAGS) $< -Wall -L$(HADOOP_HOME)/c++/Linux-amd64-64/lib -lhadooppipes -lhadooputils -lpthread -g -O2 -o $@

clean:
	$(RM) -rf $(PROGRAM) $(OBJS)
