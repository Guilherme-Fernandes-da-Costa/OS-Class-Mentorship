# OS-Class-Mentorship

*Motivação*:
pq sim.

*Como executar o xv6 + Docker?*
1. baixe os arquivos Makefile e 'xv6 (xv6 + Docker)'.zip
2. Execute o Makefile
3. Descomprima o .zip
4. execute
   ```bash
   cd ./xv6_dev/xv6-public
   ```
5. execute
   ```bash
   sudo docker run --rm -it -v $(pwd):/xv6-public xv6-docker
   ```
7. A PARTIR DAQUI JÁ ESTARÁ DENTRO DO QEMU:
8. execute
   ```bash
   make && make qemu-nox
   ```
9. Vc já estará no xv6, aproveite o EP :).

Obs:
*Como sair do xv6?*\
Ctrl+A, ou só fechar o terminal mesmo.
