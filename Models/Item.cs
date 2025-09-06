namespace WarehouseApp.Models
{
    public class Item
    {
        public int ItemID { get; set; }
        public string Name { get; set; }
        public string Code { get; set; }
        public int Quantity { get; set; }
        public int MinQuantity { get; set; }
        public string? Supplier { get; set; }

        // ÃÖİ ÇáÎÇÕíÉ Ïí ÅĞÇ ßäÊ ãÍÊÇÌåÇ
        public DateTime LastUpdate { get; set; }
    }
}
