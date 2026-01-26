import sys
import os

# --- DIAGNOSTIC SYSTEM ---
try:
    import pandas as pd
    import matplotlib.pyplot as plt
    import matplotlib.transforms as mtransforms
    from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg, NavigationToolbar2Tk
    from mpl_toolkits.axes_grid1 import make_axes_locatable
    import tkinter as tk
    from tkinter import filedialog, messagebox, ttk
    import numpy as np
    from scipy.stats import gaussian_kde
except Exception as e:
    print(f"\nCRITICAL ERROR: {e}")
    input("Press ENTER to close...")
    sys.exit(1)

class LyraAnalyserGUI:
    def __init__(self, root):
        self.root = root
        self.root.title("Lyra Framework Analyser - IFSP & UNIVALI")
        self.root.state('zoomed')
        self.root.configure(bg="#f5f6f7")
        
        self.lang_ui = tk.StringVar(value="pt-br") 
        self.lang_plot = tk.StringVar(value="en")  
        self.invert_map = tk.BooleanVar(value=False)
        self.df = None
        self.canvas = None
        self.toolbar = None
        
        # References for tight bbox saving
        self.cax_b_ref = None
        self.cax_r_ref = None
        
        self.setup_menu() 
        self.setup_layout()
        self.setup_ui()
        self.root.protocol("WM_DELETE_WINDOW", self.on_closing)

    def get_text(self, key, lang):
        texts = {
            "ui": {
                "en": {"open": "📂 OPEN LOG CSV", "save": "💾 SAVE IMAGES", "invert": "Invert X ↔ Z", "perf_title": "Group Performance", "t_total": "Total Time", "dist": "Total Distance", "speed": "Avg. Speed", "menu_lang": "Language"},
                "pt-br": {"open": "📂 ABRIR LOG CSV", "save": "💾 SALVAR IMAGENS", "invert": "Inverter X ↔ Z", "perf_title": "Desempenho do Grupo", "t_total": "Tempo Total", "dist": "Distância Total", "speed": "Vel. Média", "menu_lang": "Linguagem"}
            },
            "plot": {
                "en": {"map_title": "SPATIO-TEMPORAL NAVIGATION ANALYSIS", "time_label": "GAME TIMELINE (Seconds)", "dens_label": "Stay Density", "eff_title": "SEARCH EFFICIENCY ANALYSIS", "x_label": "Time (s)", "y_label": "Distance (m)", "goal": "Goal", "trajectory": "Trajectory"},
                "pt-br": {"map_title": "ANÁLISE DE NAVEGAÇÃO ESPAÇO-TEMPORAL", "time_label": "LINHA DO TEMPO (Segundos)", "dens_label": "Densidade de Permanência", "eff_title": "ANÁLISE DE EFICIÊNCIA DE BUSCA", "x_label": "Tempo (s)", "y_label": "Distância (m)", "goal": "Alvo", "trajectory": "Trajetória"}
            }
        }
        return texts[key][lang]

    def setup_menu(self):
        menubar = tk.Menu(self.root)
        ui = self.get_text("ui", self.lang_ui.get())
        lang_menu = tk.Menu(menubar, tearoff=0)
        lang_menu.add_radiobutton(label="Interface: Português", variable=self.lang_ui, value="pt-br", command=self.setup_ui)
        lang_menu.add_radiobutton(label="Interface: English", variable=self.lang_ui, value="en", command=self.setup_ui)
        lang_menu.add_separator()
        lang_menu.add_radiobutton(label="Plots: Português", variable=self.lang_plot, value="pt-br", command=self.update_plots)
        lang_menu.add_radiobutton(label="Plots: English", variable=self.lang_plot, value="en", command=self.update_plots)
        menubar.add_cascade(label=ui["menu_lang"], menu=lang_menu)
        self.root.config(menu=menubar)

    def setup_layout(self):
        self.side_panel = tk.Frame(self.root, width=220, bg="#ffffff", bd=0)
        self.side_panel.pack(side=tk.LEFT, fill=tk.Y, padx=5, pady=5)
        self.side_panel.pack_propagate(False)
        self.viz_container = tk.Frame(self.root, bg="white")
        self.viz_container.pack(side=tk.RIGHT, fill=tk.BOTH, expand=True, padx=5, pady=5)
        self.toolbar_frame = tk.Frame(self.viz_container, bg="#ffffff")
        self.toolbar_frame.pack(side=tk.BOTTOM, fill=tk.X)

    def setup_ui(self):
        for widget in self.side_panel.winfo_children(): widget.destroy()
        ui = self.get_text("ui", self.lang_ui.get())
        self.setup_menu() 
        tk.Label(self.side_panel, text="Lyra Analyser", font=("Segoe UI", 14, "bold"), bg="#ffffff", fg="#34495e").pack(pady=20)
        btn_style = {"font": ("Segoe UI", 9, "bold"), "relief": tk.FLAT, "width": 20, "height": 2}
        tk.Button(self.side_panel, text=ui["open"], command=self.load_file, bg="#27ae60", fg="white", **btn_style).pack(pady=10)
        tk.Checkbutton(self.side_panel, text=ui["invert"], variable=self.invert_map, command=self.update_plots, bg="#ffffff").pack(pady=5)
        tk.Button(self.side_panel, text=ui["save"], command=self.save_plots, bg="#2980b9", fg="white", **btn_style).pack(pady=10)
        
        self.perf_frame = tk.LabelFrame(self.side_panel, text=ui["perf_title"], font=("Segoe UI", 8, "bold"), bg="#ffffff", padx=10, pady=10)
        self.perf_frame.pack(side=tk.TOP, fill=tk.X, pady=20, padx=10)
        self.lbl_stats = tk.Label(self.perf_frame, text="...", bg="#ffffff", font=("Segoe UI", 9), justify=tk.LEFT)
        self.lbl_stats.pack()
        
        tk.Label(self.side_panel, text="João Antônio Temochko Andre \nJohnata Souza Santicioli\nIFSP", font=("Segoe UI", 7), bg="#ffffff", fg="#95a5a6").pack(side=tk.BOTTOM, pady=10)
        if self.df is not None: self.update_stats_label()

    def update_stats_label(self):
        ui = self.get_text("ui", self.lang_ui.get())
        t_start = self.df['timestamp'].min()
        t_total = self.df['timestamp'].max() - t_start
        dist_total = np.sqrt(self.df['x'].diff()**2 + self.df['z'].diff()**2).sum()
        avg_speed = dist_total / t_total if t_total > 0 else 0
        self.lbl_stats.config(text=f"{ui['t_total']}: {t_total:.1f}s\n{ui['dist']}: {dist_total:.1f}m\n{ui['speed']}: {avg_speed:.2f}m/s")
        return f"Time: {t_total:.1f}s | Speed: {avg_speed:.2f}m/s"

    def load_file(self):
        path = filedialog.askopenfilename(filetypes=[("CSV Files", "*.csv")])
        if not path: return
        try:
            valid_rows = []
            with open(path, 'r', encoding='utf-8', errors='ignore') as f:
                for line in f:
                    parts = line.strip().split(';')
                    if len(parts) >= 8 and parts[0].replace('.', '').isdigit():
                        valid_rows.append(parts[:8])
            self.df = pd.DataFrame(valid_rows, columns=['timestamp', 'event', 'id', 'type', 'dist', 'x', 'y', 'z'])
            for col in ['timestamp', 'type', 'dist', 'x', 'y', 'z']:
                self.df[col] = pd.to_numeric(self.df[col].str.replace(',', '.'), errors='coerce')
            self.df = self.df.dropna(subset=['timestamp', 'x', 'z'])
            self.update_plots()
        except Exception as e:
            messagebox.showerror("Error", f"CSV Error: {e}")

    def update_plots(self):
        if self.df is None: return
        p = self.get_text("plot", self.lang_plot.get())
        stats_map = self.update_stats_label()
        t_start = self.df['timestamp'].min()

        # --- CLEANUP BEFORE REDRAW ---
        if self.canvas: self.canvas.get_tk_widget().destroy()
        
        # Destroys old toolbar to prevent duplication
        for widget in self.toolbar_frame.winfo_children():
            widget.destroy()

        # Widescreen Figure Setup
        self.fig, (self.ax1, self.ax2) = plt.subplots(2, 1, figsize=(15, 10), gridspec_kw={'height_ratios': [1.8, 1]})
        self.fig.patch.set_facecolor('white')
        plt.subplots_adjust(left=0.08, right=0.9, top=0.92, bottom=0.1, hspace=0.5)
        
        h, v = ('z', 'x') if self.invert_map.get() else ('x', 'z')
        x, y, t = self.df[h].values, self.df[v].values, (self.df['timestamp'].values - t_start)

        if len(x) > 5:
            xmin, xmax, ymin, ymax = x.min()-2, x.max()+2, y.min()-2, y.max()+2
            X, Y = np.mgrid[xmin:xmax:100j, ymin:ymax:100j]
            kernel = gaussian_kde(np.vstack([x, y]))
            Z = np.reshape(kernel(np.vstack([X.ravel(), Y.ravel()])).T, X.shape)
            
            # Heatmap Plot
            cf = self.ax1.contourf(X, Y, Z, levels=40, cmap='YlOrRd', alpha=1.0)
            sc = self.ax1.scatter(x, y, c=t, cmap='cool', s=12, alpha=0.8, edgecolors='none', label=p['trajectory'])
            
            # Colorbars Synchronization
            divider = make_axes_locatable(self.ax1)
            self.cax_b_ref = divider.append_axes("bottom", size="5%", pad=0.15)
            cb_b = self.fig.colorbar(sc, cax=self.cax_b_ref, orientation='horizontal')
            cb_b.set_label(p["time_label"], fontsize=10, fontweight='bold')
            
            self.cax_r_ref = divider.append_axes("right", size="2%", pad=0.1)
            cb_r = self.fig.colorbar(cf, cax=self.cax_r_ref)
            cb_r.set_label(p["dens_label"], fontsize=10, fontweight='bold')

            step = max(1, int(len(x)/15))
            for i in range(0, len(x), step):
                self.ax1.text(x[i], y[i], f"{t[i]:.0f}s", fontsize=7, color='black', fontweight='bold')

        # Stats Box
        self.ax1.text(0.02, 0.98, stats_map, transform=self.ax1.transAxes, fontsize=9, fontweight='bold', 
                      verticalalignment='top', bbox=dict(boxstyle='round', facecolor='white', alpha=0.8))

        # Goals Markers
        goals = self.df[self.df['type'] == 0]
        if not goals.empty:
            for g_id in goals['id'].unique():
                g = goals[goals['id'] == g_id]
                self.ax1.scatter(g[h], g[v], s=250, marker='*', color='gold', edgecolors='black', label=f"{p['goal']} {g_id}", zorder=12)
        
        self.ax1.legend(loc='upper right', fontsize='8', framealpha=0.8, markerscale=0.5)
        self.ax1.set_title(p["map_title"], fontsize=13, fontweight='bold', pad=20)
        self.ax1.set_aspect('auto')
        self.ax1.set_axis_off() 

        # Efficiency Graph
        if not goals.empty:
            for g_id in goals['id'].unique():
                g_data = goals[goals['id'] == g_id].sort_values('timestamp')
                self.ax2.plot(g_data['timestamp'] - t_start, g_data['dist'], marker='o', markersize=4, linewidth=1.5, label=f'{p["goal"]} {g_id}')
            self.ax2.set_title(p["eff_title"], fontsize=11, fontweight='bold', pad=20)
            self.ax2.set_xlabel(p["x_label"], fontsize=9); self.ax2.set_ylabel(p["y_label"], fontsize=9)
            self.ax2.legend(loc='upper right', fontsize='8', markerscale=0.6)
            self.ax2.grid(True, linestyle=':', alpha=0.6)

        # --- NAVIGATION SETTINGS ---
        self.ax1.set_navigate(False) # Lock Map
        self.ax2.set_navigate(True)  # Unlock Efficiency Graph

        self.canvas = FigureCanvasTkAgg(self.fig, master=self.viz_container)
        self.canvas.get_tk_widget().pack(side=tk.TOP, fill=tk.BOTH, expand=True)
        
        # New Toolbar creation
        self.toolbar = NavigationToolbar2Tk(self.canvas, self.toolbar_frame)
        self.toolbar.update()
        
        self.canvas.draw()

    def save_plots(self):
        if self.df is None: return
        folder = filedialog.askdirectory()
        if folder:
            try:
                renderer = self.canvas.get_renderer()
                
                # --- MAP SAVING (Includes colorbars) ---
                bbox_map = self.ax1.get_tightbbox(renderer)
                if self.cax_b_ref is not None:
                    bbox_cb_b = self.cax_b_ref.get_tightbbox(renderer)
                    bbox_map = mtransforms.Bbox.union([bbox_map, bbox_cb_b])
                if self.cax_r_ref is not None:
                    bbox_cb_r = self.cax_r_ref.get_tightbbox(renderer)
                    bbox_map = mtransforms.Bbox.union([bbox_map, bbox_cb_r])

                bbox1_final = bbox_map.transformed(self.fig.dpi_scale_trans.inverted())
                self.fig.savefig(os.path.join(folder, "navigation_analysis.png"), bbox_inches=bbox1_final.expanded(1.1, 1.1), dpi=300)
                
                # --- GRAPH SAVING ---
                bbox2 = self.ax2.get_tightbbox(renderer).transformed(self.fig.dpi_scale_trans.inverted())
                self.fig.savefig(os.path.join(folder, "efficiency_graph.png"), bbox_inches=bbox2.expanded(1.1, 1.15), dpi=300)
                
                messagebox.showinfo("Success", "Images saved successfully!")
            except Exception as e:
                messagebox.showerror("Error", f"Failed: {e}")

    def on_closing(self):
        self.root.quit(); self.root.destroy(); os._exit(0)

if __name__ == "__main__":
    root = tk.Tk(); app = LyraAnalyserGUI(root); root.mainloop()