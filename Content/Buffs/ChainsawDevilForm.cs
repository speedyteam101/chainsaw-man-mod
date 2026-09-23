using ChainsawManMod.Common.Players;
using Terraria;
using Terraria.Localization;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Buffs
{
	// The full Chainsaw Devil transformation, triggered by pulling the Starter Cord.
	public class ChainsawDevilForm : ModBuff
	{
		public static readonly int MeleeDamageBonus = 25;
		public static readonly int MeleeSpeedBonus = 15;
		public static readonly int DefenseBonus = 10;
		public static readonly int MoveSpeedBonus = 20;

		public override LocalizedText Description => base.Description.WithFormatArgs(MeleeDamageBonus, MeleeSpeedBonus, DefenseBonus, MoveSpeedBonus);

		public override void Update(Player player, ref int buffIndex) {
			player.GetModPlayer<ChainsawManPlayer>().chainsawDevilForm = true;
			player.GetDamage(DamageClass.Melee) += MeleeDamageBonus / 100f;
			player.GetAttackSpeed(DamageClass.Melee) += MeleeSpeedBonus / 100f;
			player.statDefense += DefenseBonus;
			player.moveSpeed += MoveSpeedBonus / 100f;
		}
	}
}
