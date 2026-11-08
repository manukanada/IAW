# Explícalo con tus palabras

Cuando tengas el comprobador en verde, contesta aquí sin mirar los apuntes (2–4 líneas cada una).
Es lo que te preguntarán en la defensa de la práctica.

1. ¿Qué pasa si a Nginx le falta el bloque `location ~ \.php$`? ¿Por qué es peligroso?

2. ¿Para qué sirve `try_files $uri =404;` dentro del bloque de PHP? ¿Qué hace Nginx con un `.php` que no existe, con él y sin él?

3. En `pedido.php`, ¿por qué el XSS se arregla al **imprimir** (con `e()`) y no al leer el formulario?

4. ¿Por qué en producción `display_errors` va a `Off`, pero `log_errors` a `On`? ¿Qué aprendería un atacante de un error en pantalla?

5. Explica de dónde sale tu `pm.max_children`. ¿Qué pasa si te quedas corto? ¿Y si te pasas?
