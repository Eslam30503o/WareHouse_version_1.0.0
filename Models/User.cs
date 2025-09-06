using System;
using System.ComponentModel.DataAnnotations;

namespace WarehouseApp.Models
{
    public class User
    {
        public int UserID { get; set; }

        [Required]
        [StringLength(50)]
        public string Username { get; set; }

        [Required]
        [StringLength(255)]
        public string Password { get; set; }

        [Required]
        [StringLength(20)]
        public string Role { get; set; }  // Admin, Manager, Worker

        public DateTime CreatedAt { get; set; } = DateTime.Now;
    }
}
