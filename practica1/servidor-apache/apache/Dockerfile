FROM ubuntu:24.04

RUN apt update && apt install -y apache2

COPY sites/ /etc/apache2/sites-available/

RUN a2dissite 000-default.conf && \
    a2ensite 000-default-local.conf && \
    a2ensite catlynx.conf && \
    a2ensite nodisknobuy.conf

CMD ["apachectl", "-D", "FOREGROUND"]

