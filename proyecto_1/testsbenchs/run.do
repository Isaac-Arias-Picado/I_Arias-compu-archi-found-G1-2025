# run.do — Compila todo y corre todos los testbenches
# Uso (desde testsbenchs/):   vsim -c -do run.do
# ---------- Limpiar librería previa ----------
if {[file exists work]} {
    vdel -all -lib work
}
vlib work

# ---------- Compilar src/ (pkg primero) ----------
echo "===== Compilando src/ ====="
vlog ../src/config_pkg.sv
foreach f [lsort [glob -nocomplain ../src/*.sv]] {
    if {[file tail $f] ne "config_pkg.sv"} {
        vlog $f
    }
}

# ---------- Descubrir bloques ----------
set blocks [lsort [glob -nocomplain -type d Bloque*]]

if {[llength $blocks] == 0} {
    echo "ERROR: no se encontraron subcarpetas Bloque*/ en [pwd]"
    quit -f
}

# ---------- Compilar y correr testbenches por bloque ----------
set total_errors 0

foreach blk $blocks {
    echo ""
    echo "===== Bloque: $blk ====="

    # Solo testbenches tb_*.sv. tb_top se corre aparte con el paquete acelerado.
    set tbs {}
    foreach f [lsort [glob -nocomplain -directory $blk tb_*.sv]] {
        if {[file tail $f] ne "tb_top.sv"} {
            lappend tbs $f
        }
    }
    if {[llength $tbs] == 0} {
        echo "  (sin archivos .sv, saltando)"
        continue
    }

    foreach f $tbs {
        echo "  Compilando $f"
        if {[catch {vlog $f} err]} {
            echo "  FAIL compilando $f"
            incr total_errors
            continue
        }
    }

    foreach f $tbs {
        set tbname [file rootname [file tail $f]]
        echo "  Corriendo $tbname"
        if {[catch {
            vsim work.$tbname
            onfinish stop
            run -all
            quit -sim
        } err]} {
            echo "  FAIL simulando $tbname"
            incr total_errors
        }
    }
}

# ---------- Sistema completo (tb_top) ----------
# Usa config_pkg_sim.sv en una libreria aparte, para no reemplazar
# el paquete real con el que se compilaron los demas testbenches.
echo ""
echo "===== Sistema completo: tb_top ====="
if {[file exists work_top]} {
    vdel -all -lib work_top
}
vlib work_top
if {[catch {
    vlog -work work_top BloqueC/config_pkg_sim.sv
    foreach f [lsort [glob -nocomplain ../src/*.sv]] {
        if {[file tail $f] ne "config_pkg.sv"} {
            vlog -work work_top $f
        }
    }
    vlog -work work_top BloqueC/tb_top.sv
    vsim work_top.tb_top
    onfinish stop
    run -all
    quit -sim
} err]} {
    echo "  FAIL en tb_top: $err"
    incr total_errors
}

echo ""
echo "===== Resultado: $total_errors fallo(s) ====="


quit -f