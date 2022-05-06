FROM ubuntu

# Get required dependencies to install sdkman
RUN apt-get clean
RUN apt-get update
RUN rm /bin/sh && ln -s /bin/bash /bin/sh
RUN apt-get -qq -y install curl wget unzip zip

# Install required versions of java, maven and kotlin
RUN curl -s "https://get.sdkman.io" | bash
RUN source "$HOME/.sdkman/bin/sdkman-init.sh" && \
    yes | sdk install java 11.0.10-open && \
    yes | sdk install maven 3.8.1 && \
    yes | sdk install kotlin 1.4.31

# Copy testing folder and required keys for testing
COPY tests/ tests/
COPY keys/ keys/

# Pre-install java and kotlin libraries required
RUN source "$HOME/.sdkman/bin/sdkman-init.sh" && \
    cd tests && mvn package -Dmaven.test.skip

# Run tests
CMD source "$HOME/.sdkman/bin/sdkman-init.sh" && cd tests && mvn clean test && mvn clean