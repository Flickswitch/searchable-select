export const SearchableSelect = {
    mounted() {
        this.handleEvent("searchable_select", ({id: id}) => {
            if (this.el.id === id) {
                this.el.focus({preventScroll: true})
                this.el.blur()
                this.el.dispatchEvent(new Event('change', { 'bubbles': true }))
            }
        })
    },
}
