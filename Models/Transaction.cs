using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace WarehouseApp.Models
{
    public class Transaction
    {
        public int TransactionID { get; set; }

        // ÚáÇŞÉ ãÚ User
        [ForeignKey("User")]
        public int UserID { get; set; }
        public User User { get; set; }

        // ÚáÇŞÉ ãÚ Item
        [ForeignKey("Item")]
        public int ItemID { get; set; }
        public Item Item { get; set; }

        [Required]
        [StringLength(50)]
        public string Action { get; set; }  // ãËáÇ Add / Remove

        public int QuantityChange { get; set; }

        public DateTime Timestamp { get; set; } = DateTime.Now;
    }
}
