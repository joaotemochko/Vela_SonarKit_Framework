import pandas as pd
import matplotlib.pyplot as plt
import tkinter as tk
from tkinter import filedialog
import os

def get_csv_path():
    # Abre uma janela para você selecionar o arquivo CSV
    root = tk.Tk()
    root.withdraw() # Esconde a janela principal do tkinter
    print("Selecione o arquivo de log do Lyra (.csv)...")
    file_path = filedialog.askopenfilename(
        title="Selecione o Log do Lyra",
        filetypes=[("Arquivos CSV", "*.csv")]
    )
    return file_path

def run_analysis():
    path = get_csv_path()
    if not path:
        print("Nenhum arquivo selecionado. Saindo...")
        return

    # Nomes das colunas conforme definido no seu LyraCore.gd
    cols = ['timestamp', 'event', 'id', 'dist', 'x', 'y', 'z']
    
    try:
        # Lendo os dados
        df = pd.read_csv(path, sep=';', names=cols, header=0)
        
        # Criando a figura com dois subplots (Trajetória e Proximidade)
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 6))
        fig.suptitle(f'Análise de Navegação - Projeto Lyra (IFSP)\nArquivo: {os.path.basename(path)}')

        # 1. Gráfico de Trajetória (X, Z) - Visão Superior
        ax1.plot(df['x'], df['z'], color='#2ca02c', label='Trajetória Percorrida', linewidth=1.5)
        
        # Marcar onde o som foi ativado (ENTER)
        enters = df[df['event'] == 'ENTER']
        ax1.scatter(enters['x'], enters['z'], color='red', label='Aproximação de Obstáculo', s=30, zorder=3)
        
        ax1.set_title('Mapa de Movimentação (Top-Down)')
        ax1.set_xlabel('Posição X')
        ax1.set_ylabel('Posição Z')
        ax1.legend()
        ax1.grid(True, linestyle='--', alpha=0.7)

        # 2. Gráfico de Proximidade (Tempo vs Distância)
        ax2.plot(df['timestamp'], df['dist'], color='#1f77b4')
        ax2.fill_between(df['timestamp'], df['dist'], color='#1f77b4', alpha=0.1)
        
        ax2.set_title('Histórico de Proximidade dos Objetos')
        ax2.set_xlabel('Tempo de Jogo (Segundos)')
        ax2.set_ylabel('Distância (Unidades Godot)')
        ax2.grid(True, linestyle='--', alpha=0.7)

        # Salvar o resultado
        output_name = path.replace('.csv', '_analise.png')
        plt.tight_layout(rect=[0, 0.03, 1, 0.95])
        plt.savefig(output_name)
        print(f"Sucesso! Gráficos salvos em: {output_name}")
        plt.show()

    except Exception as e:
        print(f"Erro ao processar os dados: {e}")

if __name__ == "__main__":
    run_analysis()