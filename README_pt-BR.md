# Lyra Godot Framework 🌌
**Um Framework de Sonificação Espacial e Telemetria para Acessibilidade 3D.**

O Lyra Godot Framework é uma ferramenta especializada desenvolvida para o **Instituto Federal de Educação, Ciência e Tecnologia de São Paulo (IFSP)** e **Universidade do Vale do Itajaí (UNIVALI)**. Ele foi projetado para facilitar a navegação autônoma de usuários com deficiência visual em ambientes virtuais 3D, convertendo a topologia espacial em feedback auditivo em tempo real.

## 🔬 Propósito da Pesquisa

Este framework foi desenvolvido como parte de um projeto de pesquisa em **Jogos Digitais e Psicologia**. Seu objetivo principal é investigar a **Sonificação Espacial** como um método viável para orientação não visual (*wayfinding*).

A ferramenta atende a dois objetivos científicos principais:
1.  **Tecnologia Assistiva:** Fornecer uma solução de baixo custo e código aberto para criar jogos digitais 3D acessíveis e ambientes educacionais.
2.  **Análise Comportamental:** Capturar telemetria de alta precisão (posição, tempo de hesitação, desvio de trajetória) para estudos de **Psicologia Ambiental**. Essas métricas ajudam a validar se as pistas auditivas reduzem efetivamente a carga cognitiva e os erros de navegação na ausência de estímulos visuais.

---

## 🚀 Principais Recursos

* **Auto-Injeção Adaptativa:** Escaneia automaticamente a árvore da cena para anexar emissores de áudio a nós `CollisionShape3D`, `Area3D` ou `MeshInstance3D`.
* **Pooling Acústico Virtual:** Gerenciamento de áudio otimizado que instancia reprodutores (*players*) na raiz da cena, permitindo paisagens sonoras de alta densidade com impacto mínimo na performance.
* **Feedback Psicoacústico Dinâmico:** Modulação em tempo real de volume e tom (*pitch*) com base na proximidade e no tipo de interação (ex: Obstáculos vs. Objetivos).
* **Telemetria de Grau de Pesquisa:** Sistema de registro integrado que gera arquivos `.csv` contendo carimbos de tempo, gatilhos de eventos e coordenadas 3D precisas (X, Y, Z) para análise comportamental.

## 🛠️ Instalação e Configuração

1.  Copie a pasta `addons/Lyra_Framework` para o diretório `res://addons/` do seu projeto.
2.  Ative o plugin em **Projeto > Configurações do Projeto > Plugins**.
3.  O framework registrará automaticamente o singleton `LyraCore` (se configurado) ou você pode instanciá-lo manualmente dentro de seus emissores.
4.  Configure a variável de exportação `Radar` no nó `LyraEmitter` para selecionar qual tipo de geometria monitorar.

## 📊 Lyra Analyser (Visualização Científica)

O framework inclui o **Lyra Analyser**, um utilitário robusto baseado em Python projetado para pesquisa acadêmica (Psicologia e IHC). Ele processa logs de telemetria para gerar figuras de alta resolução adequadas para publicações científicas.

### Principais Recursos Analíticos:

* **Mapas de Calor Espaço-Temporais:**
    * **Densidade de Permanência:** Visualiza áreas de hesitação usando um gradiente de alto contraste `YlOrRd`.
    * **Trajetória Cronológica:** Plota o caminho do usuário com um mapa de cores `Cool` sincronizado, vinculando a posição espacial à **Linha do Tempo**.
* **Análise de Eficiência de Busca:**
    * Gera gráficos correlacionando **Distância ao Alvo vs. Tempo**, permitindo a medição precisa do desempenho de navegação.
* **Suporte a Dois Idiomas (I18n):**
    * Suporte nativo para **Inglês** e **Português (PT-BR)** tanto para a Interface quanto para a geração de Gráficos.
* **Exportação Inteligente:**
    * Salva imagens como arquivos individuais de alta DPI com margens expandidas para evitar cortes nos títulos.

### Como Executar

1.  **Instalar Dependências:**
    ```bash
    pip install pandas matplotlib scipy numpy
    ```

2.  **Iniciar a Ferramenta:**
    ```bash
    python lyra_analyser.py
    ```

3.  **Fluxo de Trabalho:**
    * Carregue um log de sessão `.csv`.
    * Selecione seu idioma preferido (EN/PT-BR).
    * Analise as métricas (Tempo Total, Distância, Velocidade).
    * Exporte gráficos de alta qualidade.

---

**Autores:**
* João Antônio Temochko Andre - Instituto Federal de Educação, Ciência e Tecnologia de São Paulo (IFSP)
* Johnata Souza Santicioli - Instituto Federal de Educação, Ciência e Tecnologia de São Paulo (IFSP)
* Carolina André da Silva - Universidade do Vale do Itajaí (UNIVALI)

**Instituições:**
* Instituto Federal de Educação, Ciência e Tecnologia de São Paulo (IFSP)
* Universidade do Vale do Itajaí (UNIVALI)