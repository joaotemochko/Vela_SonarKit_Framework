import sys
import os

try:
    import pandas as pd
    import matplotlib.pyplot as plt
    from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg, NavigationToolbar2Tk
    import tkinter as tk
    from tkinter import filedialog, messagebox, ttk
    import numpy as np
    from scipy.stats import gaussian_kde
except Exception as e:
    print(f"\nERRO CRÍTICO: {e}")
    sys.exit(1)

class LyraAnalyserGUI:
    def __init__(self, root):
        self.root = root
        self.root.title("Lyra Analyser - Scientific Research v1.1 - IFSP & UNIVALI")
        self.root.state('zoomed')
        self.root.configure(bg="#dcdcdc")
        
        # Variáveis
        self.lang_ui = tk.StringVar(value="pt-br")
        self.lang_plot = tk.StringVar(value="en")
        self.df = None
        self.static_goals = []
        self.zoom_factor = 1.0 # Controle de Zoom Manual
        
        # Configuração Global
        plt.rcParams.update({
            'font.family': 'sans-serif', 'font.size': 10,
            'axes.titlesize': 12, 'axes.labelsize': 10, 'figure.autolayout': True
        })
        
        self.setup_ui()
        self.root.protocol("WM_DELETE_WINDOW", self.on_closing)

    def get_text(self, context, key):
        lang = self.lang_ui.get() if context == 'ui' else self.lang_plot.get()
        texts = {
            "ui": {
                "en": { 
                    "open": "📂 LOAD DATA", "save": "💾 EXPORT GRAPHS", 
                    "metrics": "Psycho-Metrics", "t_total": "Duration", 
                    "dist": "Path Length", "avg_spd": "Avg Speed", 
                    "hesit": "Hesitation Time", "hits": "Goals Reached", 
                    "dev": "Authors:", "inst": "Institutions:",
                    "z_in": "Zoom In (+)", "z_out": "Zoom Out (-)"
                },
                "pt-br": { 
                    "open": "📂 CARREGAR DADOS", "save": "💾 EXPORTAR GRÁFICOS", 
                    "metrics": "Psico-Métricas", "t_total": "Duração Total", 
                    "dist": "Caminho Percorrido", "avg_spd": "Velocidade Média", 
                    "hesit": "Tempo de Hesitação", "hits": "Alvos Alcançados", 
                    "dev": "Autores:", "inst": "Instituições:",
                    "z_in": "Aumentar Zoom (+)", "z_out": "Diminuir Zoom (-)"
                }
            },
            "plot": {
                "en": {
                    "map_title": "A. SPATIAL COGNITION MAP (Trajectory & Success)",
                    "goal_title": "B. TASK PERFORMANCE (Goal Seeking Phases)",
                    "bound_title": "C. SAFETY BUFFER (Distance from Hazard)",
                    "x_time": "Time (s)", "y_dist": "Distance (m)", 
                    "x_pos": "X Position (m)", "y_pos": "Z Position (m)",
                    "leg_traj": "Subject Path", "leg_hit": "Success (Hit)", 
                    "leg_miss": "Missed Goal", "leg_dwell": "Cognitive Stop",
                    "leg_safe": "Safety Margin", "leg_danger": "CRITICAL ZONE",
                    "start": "START", "end": "END"
                },
                "pt-br": {
                    "map_title": "A. MAPA DE COGNIÇÃO ESPACIAL (Trajetória e Sucesso)",
                    "goal_title": "B. DESEMPENHO DA TAREFA (Fases de Busca)",
                    "bound_title": "C. BUFFER DE SEGURANÇA (Distância do Perigo)",
                    "x_time": "Tempo (s)", "y_dist": "Distância (m)", 
                    "x_pos": "Posição X (m)", "y_pos": "Posição Z (m)",
                    "leg_traj": "Trajeto", "leg_hit": "Sucesso (Hit)", 
                    "leg_miss": "Alvo Perdido", "leg_dwell": "Parada Cognitiva",
                    "leg_safe": "Margem de Segurança", "leg_danger": "ZONA CRÍTICA",
                    "start": "INÍCIO", "end": "FIM"
                }
            }
        }
        return texts[context][lang].get(key, key)

    def setup_ui(self):
        main = tk.Frame(self.root, bg="#dcdcdc")
        main.pack(fill=tk.BOTH, expand=True)
        
        # --- SIDEBAR ---
        sidebar = tk.Frame(main, width=270, bg="#2d3436")
        sidebar.pack(side=tk.LEFT, fill=tk.Y)
        sidebar.pack_propagate(False)
        
        # --- RIGHT SIDE (PREVIEW) ---
        self.right_frame = tk.Frame(main, bg="#b2bec3")
        self.right_frame.pack(side=tk.RIGHT, fill=tk.BOTH, expand=True)
        
        # Toolbar Container (Topo Fixo) - Agora com botões de Zoom
        self.top_controls = tk.Frame(self.right_frame, bg="#ecf0f1", height=40)
        self.top_controls.pack(side=tk.TOP, fill=tk.X)
        
        # Frame específico para a NavigationToolbar do Matplotlib (para evitar duplicação)
        self.mpl_toolbar_frame = tk.Frame(self.top_controls, bg="#ecf0f1")
        self.mpl_toolbar_frame.pack(side=tk.LEFT, fill=tk.X, expand=True)

        # Botões de Zoom Manual
        self.zoom_frame = tk.Frame(self.top_controls, bg="#ecf0f1")
        self.zoom_frame.pack(side=tk.RIGHT, padx=10)
        
        # --- SCROLLABLE CANVAS ---
        self.canvas_container = tk.Canvas(self.right_frame, bg="#b2bec3")
        self.scrollbar_y = tk.Scrollbar(self.right_frame, orient="vertical", command=self.canvas_container.yview)
        self.scrollbar_x = tk.Scrollbar(self.right_frame, orient="horizontal", command=self.canvas_container.xview)
        
        self.scrollable_frame = tk.Frame(self.canvas_container, bg="#b2bec3")
        self.scrollable_frame.bind(
            "<Configure>",
            lambda e: self.canvas_container.configure(scrollregion=self.canvas_container.bbox("all"))
        )
        
        self.canvas_container.create_window((0, 0), window=self.scrollable_frame, anchor="nw")
        self.canvas_container.configure(yscrollcommand=self.scrollbar_y.set, xscrollcommand=self.scrollbar_x.set)
        
        self.scrollbar_y.pack(side="right", fill="y")
        self.scrollbar_x.pack(side="bottom", fill="x")
        self.canvas_container.pack(side="left", fill="both", expand=True)

        # --- SIDEBAR WIDGETS ---
        T = lambda k: self.get_text('ui', k)
        
        tk.Label(sidebar, text="Lyra Analyser", font=("Segoe UI", 18, "bold"), fg="#00cec9", bg="#2d3436").pack(pady=(30, 5))
        tk.Label(sidebar, text="Scientific Research v1.1", font=("Segoe UI", 9), fg="#b2bec3", bg="#2d3436").pack(pady=(0, 20))
        
        btn = {"font": ("Segoe UI", 10, "bold"), "relief": "flat", "pady": 8, "cursor": "hand2"}
        tk.Button(sidebar, text=T("open"), command=self.load_file, bg="#0984e3", fg="white", **btn).pack(fill=tk.X, padx=20, pady=10)
        tk.Button(sidebar, text=T("save"), command=self.save_all, bg="#00b894", fg="white", **btn).pack(fill=tk.X, padx=20, pady=10)
        
        fr_metrics = tk.LabelFrame(sidebar, text=T("metrics"), fg="white", bg="#2d3436", font=("Segoe UI", 9, "bold"))
        fr_metrics.pack(fill=tk.X, padx=20, pady=30)
        self.lbl_stats = tk.Label(fr_metrics, text="--", fg="#dfe6e9", bg="#2d3436", font=("Consolas", 10), justify=tk.LEFT)
        self.lbl_stats.pack(anchor="w", padx=10, pady=10)

        fr_l = tk.Frame(sidebar, bg="#2d3436")
        fr_l.pack(side=tk.BOTTOM, fill=tk.X, padx=20, pady=10)
        tk.Radiobutton(fr_l, text="English", variable=self.lang_plot, value="en", command=self.update_preview, bg="#2d3436", fg="white", selectcolor="#2d3436").pack(anchor="w")
        tk.Radiobutton(fr_l, text="Português (BR)", variable=self.lang_plot, value="pt-br", command=self.update_preview, bg="#2d3436", fg="white", selectcolor="#2d3436").pack(anchor="w")

        cred = tk.Frame(sidebar, bg="#2d3436")
        cred.pack(side=tk.BOTTOM, fill=tk.X, padx=20, pady=20)
        tk.Label(cred, text="IFSP & UNIVALI", fg="white", bg="#2d3436", font=("Segoe UI", 9, "bold")).pack(anchor="w", pady=(0, 5))
        tk.Label(cred, text=T("dev"), fg="#00cec9", bg="#2d3436", font=("Segoe UI", 8, "bold")).pack(anchor="w")
        tk.Label(cred, text="João Antônio Temochko Andre\nJohnata Souza Santicioli\nCarolina André da Silva", fg="white", bg="#2d3436", font=("Segoe UI", 8), justify=tk.LEFT).pack(anchor="w")

        # Botões de Zoom UI
        self.btn_zin = tk.Button(self.zoom_frame, text="[ + ] Zoom In", command=lambda: self.apply_zoom(0.8), bg="#bdc3c7", font=("Segoe UI", 9, "bold"))
        self.btn_zout = tk.Button(self.zoom_frame, text="[ - ] Zoom Out", command=lambda: self.apply_zoom(1.2), bg="#bdc3c7", font=("Segoe UI", 9, "bold"))
        self.btn_zin.pack(side=tk.LEFT, padx=5)
        self.btn_zout.pack(side=tk.LEFT, padx=5)

    def get_hits(self):
        if self.df is None: return pd.DataFrame()
        in_zone = (self.df['dist_goal'] <= 0.1)
        entries = (in_zone.astype(int).diff().fillna(0) == 1)
        if in_zone.iloc[0]: entries.iloc[0] = True
        return self.df[entries]

    def get_stats_data(self):
        if self.df is None: return {}
        dur = self.df['timestamp'].max() - self.df['timestamp'].min()
        dist = np.sqrt(self.df['x'].diff()**2 + self.df['z'].diff()**2).sum()
        avg_speed = self.df['speed'].mean()
        hesit_time = self.df[self.df['speed_smooth'] < 0.2]['dt'].sum()
        hesit_pct = (hesit_time / dur * 100) if dur > 0 else 0
        hits = len(self.get_hits())
        return { "dur": dur, "dist": dist, "spd": avg_speed, "pct": hesit_pct, "hits": hits }

    def update_stats(self):
        d = self.get_stats_data()
        if not d: return
        T = lambda k: self.get_text('ui', k)
        txt = f"{T('t_total')}: {d['dur']:.1f} s\n{T('dist')}: {d['dist']:.1f} m\n{T('avg_spd')}: {d['spd']:.2f} m/s\n{T('hesit')}: {d['pct']:.1f}%\n{T('hits')}: {d['hits']}"
        self.lbl_stats.config(text=txt)

    def load_file(self):
        path = filedialog.askopenfilename(filetypes=[("CSV", "*.csv")])
        if not path: return
        try:
            self.static_goals = []
            valid = []
            with open(path, 'r', encoding='utf-8', errors='ignore') as f:
                for line in f:
                    p = line.strip().split(';')
                    if len(p) < 2: continue
                    if p[1] == "MAP_GOAL":
                        try: self.static_goals.append({'id': p[2], 'x': float(p[7].replace(',','.')), 'z': float(p[9].replace(',','.'))})
                        except: pass
                    elif p[1] in ["TRACK", "ENTER"]:
                        while len(p) < 10: p.append("0")
                        valid.append(p[:10])
            
            self.df = pd.DataFrame(valid, columns=['timestamp','event','id','type','dist_local','dist_goal','dist_bound','x','y','z'])
            for c in ['timestamp','dist_goal','dist_bound','x','z']:
                self.df[c] = pd.to_numeric(self.df[c].str.replace(',','.'), errors='coerce')
            self.df = self.df.dropna(subset=['timestamp','x','z']).sort_values('timestamp')
            
            self.df.loc[self.df['dist_goal'] <= 3.0, 'dist_goal'] = 0.0
            self.df['dist_bound'] = self.df['dist_bound'].clip(lower=0.0)
            self.df['dt'] = self.df['timestamp'].diff().fillna(1.0)
            self.df['dx'] = np.sqrt(self.df['x'].diff()**2 + self.df['z'].diff()**2).fillna(0)
            self.df['speed'] = (self.df['dx'] / self.df['dt']).fillna(0)
            self.df['speed_smooth'] = self.df['speed'].rolling(5).mean().fillna(0)

            self.update_stats()
            self.update_preview()
        except Exception as e: messagebox.showerror("Erro", str(e))

    def apply_zoom(self, factor):
        if not hasattr(self, 'ax_map'): return
        
        # Pega limites atuais
        xlim = self.ax_map.get_xlim()
        ylim = self.ax_map.get_ylim()
        
        # Calcula centro
        cx = (xlim[0] + xlim[1]) / 2
        cy = (ylim[0] + ylim[1]) / 2
        
        # Calcula nova largura/altura
        w = (xlim[1] - xlim[0]) * factor
        h = (ylim[1] - ylim[0]) * factor
        
        # Aplica novos limites
        self.ax_map.set_xlim(cx - w/2, cx + w/2)
        self.ax_map.set_ylim(cy - h/2, cy + h/2)
        
        self.canvas.draw()

    # --- PLOTAGEM ---

    def plot_map(self, ax):
        self.ax_map = ax # Salva referência para Zoom
        P = lambda k: self.get_text('plot', k)
        ax.clear()
        ax.set_facecolor('#eaeaf2')
        
        track = self.df[self.df['event'] == 'TRACK']
        if track.empty: return
        x, z = track['x'], track['z']

        all_x = list(x) + [g['x'] for g in self.static_goals]
        all_z = list(z) + [g['z'] for g in self.static_goals]
        if all_x:
            mx, Mx = min(all_x), max(all_x); mz, Mz = min(all_z), max(all_z)
            margin = 3.0
            ax.set_xlim(mx - margin, Mx + margin)
            ax.set_ylim(mz - margin, Mz + margin)

        try:
            stops = track[track['speed_smooth'] < 0.2]
            if len(stops) > 5:
                pos = np.vstack([stops['x'], stops['z']])
                k = gaussian_kde(pos, bw_method=0.3)
                xx, zz = np.mgrid[ax.get_xlim()[0]:ax.get_xlim()[1]:100j, ax.get_ylim()[0]:ax.get_ylim()[1]:100j]
                Z = np.reshape(k(np.vstack([xx.ravel(), zz.ravel()])).T, xx.shape)
                ax.contourf(xx, zz, Z, levels=12, cmap="Reds", alpha=0.5, zorder=1)
        except: pass

        final_hits = self.get_hits()
        
        if not final_hits.empty:
            ax.scatter(final_hits['x'], final_hits['z'], c='#f1c40f', s=350, marker='*', edgecolors='black', zorder=5, label=P("leg_hit"))
            for i, (idx, row) in enumerate(final_hits.iterrows()):
                ax.text(row['x'], row['z']+0.8, str(i+1), color='black', fontweight='bold', ha='center', va='bottom', zorder=6)

        if len(final_hits) < len(self.static_goals):
            collected_indices = []
            for i, g in enumerate(self.static_goals):
                if not final_hits.empty:
                    dists = np.sqrt((final_hits['x'] - g['x'])**2 + (final_hits['z'] - g['z'])**2)
                    if dists.min() < 10.0: collected_indices.append(i)
            
            missed_x = [self.static_goals[i]['x'] for i in range(len(self.static_goals)) if i not in collected_indices]
            missed_z = [self.static_goals[i]['z'] for i in range(len(self.static_goals)) if i not in collected_indices]
            if missed_x:
                ax.scatter(missed_x, missed_z, s=120, marker='X', color='#e74c3c', linewidth=2, label=P("leg_miss"), zorder=2)

        ax.plot(x, z, color='black', linewidth=1.5, alpha=0.9, label=P("leg_traj"), zorder=3)
        
        ax.text(x.iloc[0], z.iloc[0], P("start"), color='green', fontweight='bold', ha='right', zorder=10)
        ax.plot(x.iloc[0], z.iloc[0], 'g^', zorder=10)
        ax.text(x.iloc[-1], z.iloc[-1], P("end"), color='red', fontweight='bold', ha='left', zorder=10)
        ax.plot(x.iloc[-1], z.iloc[-1], 'rs', zorder=10)

        ax.set_title(P("map_title"), fontweight='bold', pad=12)
        ax.set_xlabel(P("x_pos")); ax.set_ylabel(P("y_pos"))
        ax.set_aspect('equal')
        ax.grid(True, linestyle=':', color='white')
        ax.legend(loc='upper right', framealpha=0.9, fontsize=8)

    def plot_efficiency(self, ax):
        P = lambda k: self.get_text('plot', k)
        ax.clear()
        t = self.df['timestamp'] - self.df['timestamp'].min()
        d = self.df['dist_goal']
        
        ax.fill_between(t, d, color='#3498db', alpha=0.2)
        ax.plot(t, d, color='#0984e3', linewidth=2)
        
        hits_df = self.get_hits()
        for i, row in hits_df.iterrows():
            ts = row['timestamp'] - self.df['timestamp'].min()
            ax.axvline(ts, color='#f1c40f', linestyle='--', alpha=0.8)
            ax.text(ts, d.max()*0.05, " HIT", color='#f39c12', fontweight='bold', rotation=90, va='bottom', fontsize=8)

        ax.set_title(P("goal_title"), fontweight='bold')
        ax.set_xlabel(P("x_time")); ax.set_ylabel(P("y_dist"))
        ax.grid(True, linestyle='--', color='#bdc3c7')
        ax.set_ylim(bottom=-0.1)
        ax.margins(x=0)

    def plot_safety(self, ax):
        P = lambda k: self.get_text('plot', k)
        ax.clear()
        t = self.df['timestamp'] - self.df['timestamp'].min()
        d = self.df['dist_bound'].replace(-1, np.nan).ffill()
        
        ax.axhspan(0, 0.5, color='#e74c3c', alpha=0.3, label=P("leg_danger"))
        ax.axhline(0, color='#c0392b', linewidth=2)
        ax.plot(t, d, color='#2d3436', linewidth=2, label=P("leg_safe"))
        
        ax.set_title(P("bound_title"), fontweight='bold')
        ax.set_xlabel(P("x_time")); ax.set_ylabel(P("y_dist"))
        ax.legend(loc='upper right', fontsize=8)
        ax.grid(True, linestyle='--', color='#bdc3c7')
        ax.set_ylim(0, max(d.max(), 2.0))
        ax.margins(x=0)

    def update_preview(self):
        if self.df is None: return
        
        # 1. Limpa toolbar antiga para evitar duplicação (CORREÇÃO CRÍTICA)
        for w in self.mpl_toolbar_frame.winfo_children(): w.destroy()
        if hasattr(self, 'toolbar'):
            self.toolbar.destroy()
            
        # 2. Limpa canvas antigo
        for w in self.scrollable_frame.winfo_children(): w.destroy()
        if hasattr(self, 'fig'): plt.close(self.fig)

        # 3. Cria nova Figura Gigante (14x24) com Ratio 3:1:1
        self.fig = plt.figure(figsize=(14, 24), dpi=90) 
        gs = self.fig.add_gridspec(3, 1, height_ratios=[3, 1, 1], hspace=0.3)
        
        self.plot_map(self.fig.add_subplot(gs[0]))
        self.plot_efficiency(self.fig.add_subplot(gs[1]))
        self.plot_safety(self.fig.add_subplot(gs[2]))
        
        self.canvas = FigureCanvasTkAgg(self.fig, master=self.scrollable_frame)
        self.canvas.draw()
        
        self.canvas.get_tk_widget().pack(fill=tk.BOTH, expand=True)
        
        # 4. Cria Toolbar Nova (após limpeza)
        self.toolbar = NavigationToolbar2Tk(self.canvas, self.mpl_toolbar_frame)
        self.toolbar.update()

    def save_all(self):
        if self.df is None: return
        folder = filedialog.askdirectory()
        if not folder: return
        try:
            dpi = 300
            f1 = plt.figure(figsize=(12, 10), dpi=dpi); self.plot_map(f1.add_subplot(111)); f1.savefig(os.path.join(folder, "1_CognitiveMap.png"), bbox_inches='tight'); plt.close(f1)
            f2 = plt.figure(figsize=(12, 6), dpi=dpi); self.plot_efficiency(f2.add_subplot(111)); f2.savefig(os.path.join(folder, "2_Performance.png"), bbox_inches='tight'); plt.close(f2)
            f3 = plt.figure(figsize=(12, 6), dpi=dpi); self.plot_safety(f3.add_subplot(111)); f3.savefig(os.path.join(folder, "3_Safety.png"), bbox_inches='tight'); plt.close(f3)
            messagebox.showinfo("OK", "3 Gráficos Salvos!")
        except Exception as e: messagebox.showerror("Erro", str(e))

    def on_closing(self):
        self.root.destroy()
        os._exit(0)

if __name__ == "__main__":
    root = tk.Tk(); app = LyraAnalyserGUI(root); root.mainloop()