# CarMashina

O projeto está organizado nas cenas abaixo.

- **cenas/seletor_carro.tscn** abre com F5. Escolha o carro na lista, confira a prévia em 3D e pressione **Ir para a pista**.
- **cenas/carro.tscn** contém as rodas, colisões e física compartilhadas. O modelo padrão é o Del Rey. Arraste esta cena para um mundo com chão que tenha colisão na camada 1. Comece com o carro cerca de 1,2 m acima do chão.
- **cenas/world.tscn**: mundo principal, com o carro, pista, chão, marcações, seis obstáculos, rampa, iluminação, câmera e velocímetro. F6 com esta cena aberta inicia a pista diretamente com o Del Rey.

- **cenas/marcador_missao.tscn** contém o cilindro vermelho e a área que detecta o carro. Para adicionar outro, arraste a cena para o nó Marcadores dentro de world.tscn e posicione sua origem no chão. Cada entrada vale R$ 1. Sair e voltar conta de novo.
- **cenas/hud.tscn** reúne o título, o velocímetro, o saldo da rodada e o aviso +1 REAL. O saldo começa em zero ao abrir o mundo.

Para editar a pista, abra world.tscn e expanda o nó **Pista**. Os objetos pertencem diretamente ao mundo e aparecem no editor. A câmera e o velocímetro ficam no mundo; não são parte do carro.

## Modelos de carro

As cenas em cenas/modelos/ contêm apenas o visual. O nome do nó raiz aparece no seletor e no painel da pista. Para incluir outro carro, crie uma cena visual com quatro rodas na ordem dianteira esquerda, dianteira direita, traseira esquerda e traseira direita. Use scripts/visual_carro.gd como base e adicione a cena à lista **Modelos** do nó raiz de seletor_carro.tscn no Inspetor. A Saveiro usa escala uniforme para atingir o comprimento de 4,555 m do Del Rey.

## Controles

W acelera; S freia e depois engata ré; A/D viram; Espaço aciona o freio de mão traseiro; R reposiciona o carro.

## Código

- scripts/delrey_car.gd: suspensão, amortecimento, tração dianteira, pneus, direção e freios.
- scripts/delrey_visual.gd: modelo original do Blender, alinhamento e animação das quatro rodas.
- scripts/drive_world.gd: câmera e velocímetro.

O GLB e as texturas em glbs/ são os arquivos originais. Massa de 980 kg, raio de pneu de 0,311 m e entre-eixos de 2,588 m são parâmetros de jogo ajustáveis, não uma reprodução certificada de um ano/motor específico. A suspensão usa raios; colisões sólidas principais são do chassi/cabine.

## Validação

O teste do seletor abre o menu e inicia a pista com cada modelo. No Godot 4.7.2 os dois mediram 4,554902 m, assentaram as quatro rodas no chão e receberam R$ 1 ao cruzar o marcador. As suítes de condução, drift, efeitos e marcador também passaram. A condução foi verificada por testes automáticos.

    godot --headless --path . --script res://tests/seletor_carro_test.gd --fixed-fps 120

Godot 4.7.2, Jolt. Testes de repouso, suspensão, aceleração, frenagem, ré, curvas, Ackermann, freio de mão, reposicionamento, inclinação, parede e tração no ar. Histórico dos testes a 60 e 120 Hz em tests/physics-60.log e tests/physics-120.log. Não houve avaliação manual prolongada da condução.

    godot --headless --path . --script res://tests/vehicle_test.gd --fixed-fps 120
    godot --headless --path . --script res://tests/vehicle_test.gd --fixed-fps 60 -- --ticks60

Cenas antigas e scripts de compatibilidade foram arquivados em backups/duas-cenas-20261104.zip. A pasta backups é ignorada pelo Godot.

## Regulagem de corrida e drift — 04/11/2026

Aceleração e direção mais rápidas, menor freio-motor e configuração arcade de tração
integral com 65% da força nas rodas traseiras. Essa configuração é uma preparação de
jogo, diferente da tração dianteira original do Del Rey. O centro de massa está mais
baixo e a suspensão mantém o carro estável apesar da bitola mais estreita.

Para iniciar drift: acima de aproximadamente 25 km/h, acelere, vire e dê um toque curto
no Espaço. Solte o Espaço e mantenha acelerador/direção para sustentar. Endireitar a
direção recupera aderência. Segurar Espaço continua sendo freio de mão e reduz a velocidade.
Há contraesterço e controle de rotação assistidos, ativos somente com contato suficiente
com o chão. Ajuste os parâmetros em Corrida e drift no Inspector do carro; drift_assist
controla a assistência e front_drive_share a distribuição de tração.

Carroceria centralizada pelo centro real da malha, rodas simétricas e bitola de 1,14 m.
Modelos e texturas originais preservados. Nenhuma cena adicional criada.

Validação no Godot 4.7.2/Jolt: 15 verificações gerais e 15 de drift/alinhamento aprovadas
em 60 e 120 Hz. O cenário automatizado com toque de 0,2 s de freio de mão produziu drift
máximo de cerca de 35 graus nos dois sentidos, com recuperação ao endireitar. Esses
números descrevem o teste e não garantem o mesmo comportamento em qualquer manobra.
Prévias frontal e lateral conferidas; sensação no teclado ainda depende da avaliação do usuário.
Logs atuais: tests/vehicle-60.log, tests/vehicle-120.log, tests/arcade-60.log e tests/arcade-120.log.

    godot --headless --path . --script res://tests/arcade_test.gd --fixed-fps 120
    godot --headless --path . --script res://tests/arcade_test.gd --fixed-fps 60 -- --ticks60

## Marcas de pneu e fumaça — 04/11/2026

Os efeitos acompanham o carro em cenas/carro.tscn, no nó EfeitosPneus. Não há cena
adicional. O script scripts/tire_effects.gd reutiliza o contato e o deslizamento
calculados pela física, sem novos raycasts e sem alterar as forças da dirigibilidade.

- Marcas: um MultiMesh com 256 trechos reutilizados (512 triângulos), largura de 18,5 cm,
  alinhados ao chão. Desaparecimento gradual; cada trecho dura até 8 segundos, podendo
  ser substituído antes quando o limite é atingido. Nenhum nó novo por trecho.
- Fumaça: dois CPUParticles3D, 10 partículas cada, vida de 1,05 segundo e atualização
  a 20 Hz. Material simples, textura radial de 32×32 compartilhada, sem luzes, sombras
  ou colisões de partículas. CPUParticles evita depender da simulação GPU de partículas.
- Emissão e manutenção das marcas a 20 Hz; sem percorrer os 256 espaços quando vazios.
  Não emite parado, sem contato ou além de 70 m da câmera. Reset limpa os efeitos;
  remover o carro libera emissores, marcas e materiais. Marcas em corpos móveis são
  omitidas para não ficarem suspensas no lugar errado.

No Inspector, selecione EfeitosPneus dentro de carro.tscn: Smoke Enabled desliga apenas
a fumaça; Effects Enabled desliga ambos. Max Segments ajusta o limite (64–512, aplicado
no início da execução); Mark Lifetime ajusta a duração antes de iniciar o jogo.

Validação: 16 verificações de efeitos aprovadas, incluindo reciclagem, expiração,
distância, reset, ausência de efeitos no ar e liberação ao remover o carro. As 15
verificações gerais e as 15 de drift também passaram. Renderização conferida no Godot
4.7.2 em Mobile/Direct3D 12 e inicialização/renderização sem erros em Compatibility/OpenGL.
Não foi medido FPS em computador de entrada; limites de quantidade não são garantia
universal de desempenho. O visual geral do cenário pode variar entre renderizadores.

    godot --headless --path . --script res://tests/tire_effects_test.gd --fixed-fps 120

Logs: tests/fx-tire_effects.log, tests/fx-arcade.log, tests/fx-vehicle.log.
Prévia: tests/drift-effects.png. Arquivos anteriores preservados em backups/antes-efeitos-*.zip.

