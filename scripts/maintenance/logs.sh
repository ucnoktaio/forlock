#!/bin/bash
#
# Forlock Log Viewer
#
# Usage:
#   ./logs.sh              # All services
#   ./logs.sh api          # API logs only
#   ./logs.sh --errors     # Only error logs
#   ./logs.sh --export     # Export logs to file
#

set -e

SERVICE="${1:-all}"
TAIL_LINES=100

# Check if running in Swarm mode
SWARM_MODE=false
if docker info 2>/dev/null | grep -q "Swarm: active"; then
    SWARM_MODE=true
fi

show_logs() {
    local svc=$1

    if [ "$SWARM_MODE" = true ]; then
        docker service logs "forlock_$svc" --tail $TAIL_LINES -f
    else
        docker logs "forlock-$svc" --tail $TAIL_LINES -f
    fi
}

show_errors() {
    echo "Searching for errors..."
    echo ""

    for svc in api frontend nginx; do
        echo "=== $svc ==="
        if [ "$SWARM_MODE" = true ]; then
            docker service logs "forlock_$svc" --tail 500 2>&1 | grep -i "error\|exception\|fail" | tail -20 || echo "No errors found"
        else
            docker logs "forlock-$svc" --tail 500 2>&1 | grep -i "error\|exception\|fail" | tail -20 || echo "No errors found"
        fi
        echo ""
    done
}

export_logs() {
    local export_dir="./logs/export_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$export_dir"

    echo "Exporting logs to $export_dir..."

    for svc in api frontend nginx postgres redis rabbitmq; do
        if [ "$SWARM_MODE" = true ]; then
            docker service logs "forlock_$svc" --tail 10000 > "$export_dir/$svc.log" 2>&1 || true
        else
            docker logs "forlock-$svc" --tail 10000 > "$export_dir/$svc.log" 2>&1 || true
        fi
    done

    # Compress
    tar -czf "${export_dir}.tar.gz" -C "$(dirname $export_dir)" "$(basename $export_dir)"
    rm -rf "$export_dir"

    echo "Exported to: ${export_dir}.tar.gz"
}

# Main
case "$1" in
    --errors)
        show_errors
        ;;
    --export)
        export_logs
        ;;
    all|"")
        if [ "$SWARM_MODE" = true ]; then
            docker service logs forlock_api --tail $TAIL_LINES -f &
            docker service logs forlock_frontend --tail $TAIL_LINES -f &
            docker service logs forlock_nginx --tail $TAIL_LINES -f
        else
            docker compose logs -f --tail $TAIL_LINES
        fi
        ;;
    *)
        show_logs "$1"
        ;;
esac
